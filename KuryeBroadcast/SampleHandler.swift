import ReplayKit
import Vision
import CoreImage

/// Saniyede en fazla 1 kare; kucult, ust serit haric oku, iki kare kuralini gecen ekranin satirlarini kaydet. Goruntu saklanmaz.
final class SampleHandler: RPBroadcastSampleHandler {
    private var log = BroadcastLog()
    private var lastProcessed = Date.distantPast
    private var filter = StableCaptureFilter()
    private let parser = EarningsScreenshotParser()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    /// Durum (log, son isleme, bekleyen kare) tek kilit altinda; ayni anda en fazla bir OCR calisir.
    private let lock = NSLock()
    private let trailingQueue = DispatchQueue(label: "kurye.broadcast.trailing")
    /// Hiz sinirina takilan en yeni kare: statik ekran icin pencere sonunda islenir.
    private var pendingBuffer: CVPixelBuffer?
    private var trailingScheduled = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        lock.lock()
        defer { lock.unlock() }
        log = BroadcastLog()
        filter = StableCaptureFilter()
        pendingBuffer = nil
        log.save()
    }

    override func broadcastFinished() {
        lock.lock()
        defer { lock.unlock() }
        pendingBuffer = nil
        log.finishedAt = .now
        log.save()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        lock.lock()
        defer { lock.unlock() }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            log.skippedRate += 1
            return
        }
        if Date().timeIntervalSince(lastProcessed) >= 1 {
            pendingBuffer = nil
            run(pixelBuffer)
        } else {
            log.skippedRate += 1
            pendingBuffer = pixelBuffer
            scheduleTrailing(after: 1 - Date().timeIntervalSince(lastProcessed))
        }
    }

    /// Kilit altinda cagrilir.
    private func run(_ pixelBuffer: CVPixelBuffer) {
        lastProcessed = Date()
        autoreleasepool { process(pixelBuffer) }
        log.peakMemoryMB = max(log.peakMemoryMB, BroadcastLog.currentMemoryMB())
        log.save()
    }

    /// Kilit altinda cagrilir. Pencere sonunda bekleyen kare islenmediyse islenir.
    private func scheduleTrailing(after delay: TimeInterval) {
        guard !trailingScheduled else { return }
        trailingScheduled = true
        trailingQueue.asyncAfter(deadline: .now() + max(0.05, delay)) { [weak self] in
            self?.runTrailing()
        }
    }

    private func runTrailing() {
        lock.lock()
        defer { lock.unlock() }
        trailingScheduled = false
        guard let pixelBuffer = pendingBuffer else { return }
        let remaining = 1 - Date().timeIntervalSince(lastProcessed)
        if remaining > 0.01 {
            scheduleTrailing(after: remaining)
            return
        }
        pendingBuffer = nil
        run(pixelBuffer)
    }

    private func process(_ pixelBuffer: CVPixelBuffer) {
        log.processed += 1
        log.lastFrameAt = .now
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let longSide = max(image.extent.width, image.extent.height)
        let scale = min(1, 1280 / longSide)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return }
        log.peakMemoryMB = max(log.peakMemoryMB, BroadcastLog.currentMemoryMB())

        let started = Date()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        // Vision koordinati alt sol koseden baslar; ust %6 (saat/durum cubugu) haric.
        request.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 0.94)
        request.recognitionLanguages = ["tr-TR", "en-US"]
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        log.peakMemoryMB = max(log.peakMemoryMB, BroadcastLog.currentMemoryMB())
        let seconds = Date().timeIntervalSince(started)
        log.totalOCRSeconds += seconds
        log.maxOCRSeconds = max(log.maxOCRSeconds, seconds)

        let lines = VisionTextRecognitionService.orderedLines(from: request.results ?? [])
        let parsed = parser.parse(lines: lines.map(\.text))
        let key = CaptureKey(parsed: parsed, calendar: .current)
        let accepted = filter.offer(key)
        log.duplicates = filter.duplicateCount
        log.unconfirmed = filter.unconfirmedCount
        if key == nil { log.unrecognized += 1 }
        guard accepted != nil else { return }
        do {
            try BroadcastCaptureStore.shared.save(BroadcastCapture(capturedAt: .now, lines: lines))
            log.accepted += 1
            if let templateID = parsed.templateID { log.captured.append(templateID) }
        } catch {
            log.saveFailures += 1
        }
    }
}

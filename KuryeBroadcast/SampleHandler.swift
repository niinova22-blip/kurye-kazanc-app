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

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        log = BroadcastLog()
        filter = StableCaptureFilter()
        log.save()
    }

    override func broadcastFinished() {
        log.finishedAt = .now
        log.save()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        let now = Date()
        guard now.timeIntervalSince(lastProcessed) >= 1,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            log.skippedRate += 1
            return
        }
        lastProcessed = now
        autoreleasepool { process(pixelBuffer) }
        log.peakMemoryMB = max(log.peakMemoryMB, BroadcastLog.currentMemoryMB())
        log.save()
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

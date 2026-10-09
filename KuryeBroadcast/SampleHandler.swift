import ReplayKit
import Vision
import CoreImage

/// DENEME: saniyede en fazla 1 kare; kucult, oku, sablon taninirsa satirlari kaydet. Goruntu saklanmaz.
final class SampleHandler: RPBroadcastSampleHandler {
    private var log = BroadcastLog()
    private var lastProcessed = Date.distantPast
    private var recentHashes: [String] = []
    private let parser = EarningsScreenshotParser()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        log = BroadcastLog()
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
        request.recognitionLanguages = ["tr-TR", "en-US"]
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        log.peakMemoryMB = max(log.peakMemoryMB, BroadcastLog.currentMemoryMB())
        let seconds = Date().timeIntervalSince(started)
        log.totalOCRSeconds += seconds
        log.maxOCRSeconds = max(log.maxOCRSeconds, seconds)

        let lines = VisionTextRecognitionService.orderedLines(from: request.results ?? [])
        let parsed = parser.parse(lines: lines.map(\.text))
        guard let templateID = parsed.templateID else {
            log.unrecognized += 1
            return
        }
        let hash = TextHash.of(lines.map(\.text))
        guard !recentHashes.contains(hash) else {
            log.duplicates += 1
            return
        }
        recentHashes.append(hash)
        if recentHashes.count > 50 { recentHashes.removeFirst() }
        log.captured.append(templateID)
        save(lines: lines, templateID: templateID)
    }

    private func save(lines: [RecognizedLine], templateID: String) {
        guard let directory = BroadcastLog.capturesDirectory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(templateID).json"
        try? RecognizedLine.encode(lines).write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}

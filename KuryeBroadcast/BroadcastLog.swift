import Foundation

/// Deneme olcumleri; App Group'ta JSON. Uygulamadaki "Tarama gunlugu" okur.
struct BroadcastLog: Codable {
    var startedAt: Date = .now
    var finishedAt: Date?
    var processed = 0
    var skippedRate = 0
    var unrecognized = 0
    var duplicates = 0
    var unconfirmed = 0
    var accepted = 0
    var saveFailures = 0
    var captured: [String] = []        // sablon kimlikleri
    var peakMemoryMB: Double = 0
    var maxOCRSeconds: Double = 0
    var totalOCRSeconds: Double = 0

    static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ScreenshotInbox.appGroupID)
    }
    static var url: URL? { directory?.appendingPathComponent("BroadcastLog.json") }

    func save() {
        guard let url = Self.url, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> BroadcastLog? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BroadcastLog.self, from: data)
    }

    /// Surecin fiziksel bellek izi (MB).
    static func currentMemoryMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }
}

import Foundation

/// Kaydin hangi yontemle girildigi. Hepsi ayni motoru ve ayni tarife surumunu kullanir.
enum EntryMethod: String, Codable, CaseIterable {
    case quick, detailed, period

    var displayName: String {
        switch self {
        case .quick: "Hızlı tahmin"
        case .detailed: "Detaylı kayıt"
        case .period: "Dönem özeti"
        }
    }
}

/// Gecmise donuk duzeltme: ayri bir islem olarak saklanir (onceki sonuc, yeni sonuc, neden, zaman).
struct Recalculation: Codable, Equatable {
    var at: Date
    var reason: String
    var previous: PayBreakdown
    var new: PayBreakdown
}

/// Gunluk (ya da donem) calisma kaydi. Tek bir platforma baglidir; olusturuldugu andaki tarife surumuyle
/// hesaplanan sonuc dondurulur. Platform ya da tarife degisse de sonuc sessizce degismez.
struct WorkLog: Codable, Equatable, Identifiable {
    var id: UUID
    var platformCode: String
    var method: EntryMethod
    var input: PayInput
    var result: PayBreakdown
    var createdAt: Date
    /// Gunluk kayitlar mevcut Bugun/Analiz ekranlarina da yansisin diye olusturulan kazanc kaydi.
    var earningRecordID: UUID? = nil
    /// Elle duzeltme (or. platform farkli odedi); ayri gosterilir.
    var manualAdjustment: Money? = nil
    var adjustmentNote: String? = nil
    var recalculations: [Recalculation] = []

    init(id: UUID = UUID(), method: EntryMethod, input: PayInput, result: PayBreakdown, createdAt: Date = Date()) {
        self.id = id
        self.platformCode = input.platformCode
        self.method = method
        self.input = input
        self.result = result
        self.createdAt = createdAt
    }

    /// Kaydin olusturuldugu andaki tarife surumu.
    var tariffVersionID: String { result.tariffVersionID }
    var startDay: String { input.startDay }
    var endDay: String { input.endDay }
    var isDaily: Bool { input.span == .day }

    var gross: Money { result.gross + (manualAdjustment ?? .zero) }

    func overlaps(start: String, end: String) -> Bool {
        startDay <= end && endDay >= start
    }
}

/// Kullanicinin girdigi gercek odeme (odeme kontrolu).
struct PaymentRecord: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var platformCode: String
    var periodStart: String
    var periodEnd: String
    var paidOn: String
    var actualAmount: Money
    var advances: Money = .zero
    var deductions: Money = .zero
    var note: String = ""
    /// Kayit anindaki beklenen tutar (sonradan degismez; yeniden karsilastirma ayri yapilir).
    var expected: Money
    var expectedUpper: Money
    var createdAt: Date = Date()
    /// Ekstreden okunan tutar kullanici onaylamadan kesin sayilmaz.
    var confirmedByUser: Bool = true

    var difference: Money { actualAmount - (expected - advances - deductions) }
}

/// Platform secim gecmisi: kullanici platform degistirince eski kayitlar silinmez ve yeniden hesaplanmaz.
struct PlatformSelection: Codable, Equatable {
    var code: String
    var from: Date
}

/// Uygulama ici tarife bildirimi.
struct TariffNotice: Codable, Equatable, Identifiable {
    var id: String
    var platformCode: String
    var title: String
    var body: String
    var effectiveFrom: String?
    var isVerified: Bool
    var createdAt: Date
    var isRead: Bool = false
}

/// Hakedis verilerinin tamami (cihazda JSON dosyasi; SwiftData semasina dokunmadan eklendi).
struct PayrollState: Codable, Equatable {
    var schemaVersion: Int = 1
    var logs: [WorkLog] = []
    var payments: [PaymentRecord] = []
    /// Kullanicinin kendi girdigi tarifeler (taslak ya da kullanici onayli).
    var userTariffs: [TariffVersion] = []
    var notices: [TariffNotice] = []
    var platformHistory: [PlatformSelection] = []
    var seenEventIDs: [String] = []
    /// Kullanicinin hakedis tercihleri (bolge kademesi, kidem, Getir arac tipi).
    var regionTier: String? = nil
    var seniorityYears: Int? = nil
    var vehicleType: String? = nil
    /// 1.7: kosula bagli kalemler icin isaretler (or. "woman_employment").
    var flags: [String] = []
    var goal: GoalSpec? = nil
    var fuel: FuelSettings = FuelSettings()
    /// Test senaryosunun olusturdugu kayitlar (yalnizca bunlar silinir).
    var demoRecordIDs: [UUID] = []
    var demoLogIDs: [UUID] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        logs = try c.decodeIfPresent([WorkLog].self, forKey: .logs) ?? []
        payments = try c.decodeIfPresent([PaymentRecord].self, forKey: .payments) ?? []
        userTariffs = try c.decodeIfPresent([TariffVersion].self, forKey: .userTariffs) ?? []
        notices = try c.decodeIfPresent([TariffNotice].self, forKey: .notices) ?? []
        platformHistory = try c.decodeIfPresent([PlatformSelection].self, forKey: .platformHistory) ?? []
        seenEventIDs = try c.decodeIfPresent([String].self, forKey: .seenEventIDs) ?? []
        regionTier = try c.decodeIfPresent(String.self, forKey: .regionTier)
        seniorityYears = try c.decodeIfPresent(Int.self, forKey: .seniorityYears)
        vehicleType = try c.decodeIfPresent(String.self, forKey: .vehicleType)
        flags = try c.decodeIfPresent([String].self, forKey: .flags) ?? []
        goal = try c.decodeIfPresent(GoalSpec.self, forKey: .goal)
        fuel = try c.decodeIfPresent(FuelSettings.self, forKey: .fuel) ?? FuelSettings()
        demoRecordIDs = try c.decodeIfPresent([UUID].self, forKey: .demoRecordIDs) ?? []
        demoLogIDs = try c.decodeIfPresent([UUID].self, forKey: .demoLogIDs) ?? []
    }

    var activePlatform: String? { platformHistory.last?.code }

    var hasChosenFirm: Bool { activePlatform != nil }

    var tariffProfile: CourierTariffProfile? {
        guard let code = activePlatform else { return nil }
        return CourierTariffProfile(platformCode: code, regionTier: regionTier, seniorityYears: seniorityYears,
                                    vehicleType: vehicleType, flags: flags)
    }
}

enum PayrollStoreError: Error, Equatable {
    /// Donem kaydi, ayni platformda gunluk kayitlari olan bir donemle cakisiyor (cift sayim).
    case periodOverlapsDailyLogs(count: Int)
    case notFound
    case userTariffNeedsSource

    var message: String {
        switch self {
        case let .periodOverlapsDailyLogs(count): "Bu dönemde \(count) günlük kayıt var; dönem özeti kaydedilmedi (çift sayılırdı). Özet tahmin olarak gösterilir."
        case .notFound: "Kayıt bulunamadı."
        case .userTariffNeedsSource: "Kendi tarifen için kaynağı belirt (ör. sözleşme, ekran görüntüsü, tarih)."
        }
    }
}

/// Hakedis deposu: Application Support altinda tek JSON dosyasi, atomik yazim. Saf Foundation (Windows'ta test edilir).
final class PayrollStore {
    private(set) var state: PayrollState
    let fileURL: URL?
    private let writeOptions: Data.WritingOptions

    /// - Parameter fileURL: nil ise yalnizca bellekte (onizleme, UI testi).
    init(fileURL: URL?, writeOptions: Data.WritingOptions = [.atomic]) {
        self.fileURL = fileURL
        self.writeOptions = writeOptions
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let decoded = try? PayrollStore.decoder.decode(PayrollState.self, from: data) {
            state = decoded
        } else {
            state = PayrollState()
        }
    }

    static let encoder: JSONEncoder = {
        // Varsayilan tarih kodlamasi (referans tarihten saniye, Double) kayipsizdir; dosya yalnizca bu cihazda okunur
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        JSONDecoder()
    }()

    private func persist() {
        guard let fileURL else { return }
        let directory: URL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? PayrollStore.encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: writeOptions)
    }

    // MARK: - Platform secimi

    var activePlatform: String? { state.activePlatform }

    /// Aktif platformu degistirir. Eski kayitlar oldugu gibi kalir.
    func select(platform code: String, at date: Date = Date()) {
        guard state.activePlatform != code else { return }
        state.platformHistory.append(PlatformSelection(code: code, from: date))
        persist()
    }

    func setPreferences(regionTier: String?, seniorityYears: Int?, vehicleType: String?) {
        state.regionTier = regionTier
        state.seniorityYears = seniorityYears
        state.vehicleType = vehicleType
        persist()
    }

    // MARK: - 1.7 hedef, yakit, isaretler

    func setFlags(_ flags: [String]) {
        state.flags = Array(Set(flags)).sorted()
        persist()
    }

    func setGoal(_ goal: GoalSpec?) {
        state.goal = goal
        persist()
    }

    func addFuelPrice(_ entry: FuelPriceEntry) {
        state.fuel.entries.append(entry)
        state.fuel.entries.sort { $0.day < $1.day }
        persist()
    }

    func deleteFuelPrice(id: UUID) {
        state.fuel.entries.removeAll { $0.id == id }
        persist()
    }

    func setConsumption(_ value: Decimal?) {
        state.fuel.consumptionPer100Km = value
        persist()
    }

    func replaceFuel(_ fuel: FuelSettings) {
        state.fuel = fuel
        persist()
    }

    func setDemoIDs(records: [UUID], logs: [UUID]) {
        state.demoRecordIDs = records
        state.demoLogIDs = logs
        persist()
    }

    func removeLogs(ids: Set<UUID>) {
        state.logs.removeAll { ids.contains($0.id) }
        persist()
    }

    // MARK: - Kayitlar

    func logs(platform: String? = nil) -> [WorkLog] {
        let all: [WorkLog] = state.logs.sorted { a, b in
            if a.startDay != b.startDay { return a.startDay > b.startDay }
            return a.createdAt > b.createdAt
        }
        guard let platform else { return all }
        return all.filter { $0.platformCode == platform }
    }

    func log(id: UUID) -> WorkLog? { state.logs.first { $0.id == id } }

    /// Donem kaydi ayni platformda gunluk kayitlarla cakisirsa reddedilir (ayni paketler iki kez sayilmasin).
    func add(_ log: WorkLog) throws {
        if log.method == .period {
            let overlapping: Int = state.logs.filter {
                $0.platformCode == log.platformCode && $0.overlaps(start: log.startDay, end: log.endDay)
            }.count
            if overlapping > 0 { throw PayrollStoreError.periodOverlapsDailyLogs(count: overlapping) }
        }
        state.logs.append(log)
        persist()
    }

    func linkEarningRecord(_ recordID: UUID, to logID: UUID) {
        guard let index = state.logs.firstIndex(where: { $0.id == logID }) else { return }
        state.logs[index].earningRecordID = recordID
        persist()
    }

    func setAdjustment(_ amount: Money?, note: String?, logID: UUID) {
        guard let index = state.logs.firstIndex(where: { $0.id == logID }) else { return }
        state.logs[index].manualAdjustment = amount
        state.logs[index].adjustmentNote = note
        persist()
    }

    @discardableResult
    func deleteLog(id: UUID) -> WorkLog? {
        guard let index = state.logs.firstIndex(where: { $0.id == id }) else { return nil }
        let removed: WorkLog = state.logs.remove(at: index)
        persist()
        return removed
    }

    /// Acik yeniden hesaplama: guncel tarifeyle hesaplanir; sonuc farkliysa onceki sonuc, yeni sonuc, neden ve zaman
    /// kayda eklenir. Hicbir zaman kendiliginden calismaz.
    func recalculate(logID: UUID, engine: PayEngine, reason: String, at date: Date = Date()) throws -> Recalculation? {
        guard let index = state.logs.firstIndex(where: { $0.id == logID }) else { throw PayrollStoreError.notFound }
        let log: WorkLog = state.logs[index]
        guard case let .success(newResult) = engine.calculate(log.input) else { return nil }
        let unchanged: Bool = newResult.tariffVersionID == log.result.tariffVersionID && newResult.lines == log.result.lines
            && newResult.sideBenefits == log.result.sideBenefits
        if unchanged { return nil }
        let entry = Recalculation(at: date, reason: reason, previous: log.result, new: newResult)
        state.logs[index].recalculations.append(entry)
        state.logs[index].result = newResult
        persist()
        return entry
    }

    // MARK: - Odemeler

    func payments(platform: String? = nil) -> [PaymentRecord] {
        let all: [PaymentRecord] = state.payments.sorted { $0.periodEnd > $1.periodEnd }
        guard let platform else { return all }
        return all.filter { $0.platformCode == platform }
    }

    func add(_ payment: PaymentRecord) {
        state.payments.append(payment)
        persist()
    }

    func deletePayment(id: UUID) {
        state.payments.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Kullanici tarifeleri

    var userTariffs: [TariffVersion] { state.userTariffs }

    /// Kullanici tarifesi kaynagiyla kaydedilir. `activate` true ise kullanici onayli (yayinda) olur ve o platformda
    /// resmi tarifenin onune gecer; aksi halde taslak kalir ve hesaplamaya girmez.
    func saveUserTariff(_ version: TariffVersion, activate: Bool) throws {
        let source: String = (version.sourceNote ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { throw PayrollStoreError.userTariffNeedsSource }
        var copy = version
        copy.origin = .user
        copy.sourceType = .userEntered
        copy.approvalStatus = activate ? .published : .draft
        copy.approvedBy = activate ? "kullanıcı" : nil
        for index in copy.items.indices where copy.items[index].confidence == .verified {
            // Kullanici girisi "dogrulanmis" etiketi alamaz
            copy.items[index].confidence = .userEntered
        }
        if let index = state.userTariffs.firstIndex(where: { $0.id == copy.id }) {
            state.userTariffs[index] = copy
        } else {
            state.userTariffs.append(copy)
        }
        persist()
    }

    func deleteUserTariff(id: String) {
        state.userTariffs.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Bildirimler

    func addNotices(_ notices: [TariffNotice], eventIDs: [String]) {
        let known: Set<String> = Set(state.notices.map(\.id))
        state.notices.append(contentsOf: notices.filter { !known.contains($0.id) })
        state.seenEventIDs = Array(Set(state.seenEventIDs).union(eventIDs)).sorted()
        persist()
    }

    var seenEventIDs: Set<String> { Set(state.seenEventIDs) }

    /// Bir kez gosterilecek olaylar (or. firma gecis onerisi) goruldu olarak isaretlenir.
    func markEventsSeen(_ ids: [String]) {
        state.seenEventIDs = Array(Set(state.seenEventIDs).union(ids)).sorted()
        persist()
    }

    func markNoticesRead(platform: String) {
        for index in state.notices.indices where state.notices[index].platformCode == platform {
            state.notices[index].isRead = true
        }
        persist()
    }
}

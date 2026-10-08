import SwiftUI
import SwiftData
import PhotosUI
import Photos

/// Kazanc ekle / duzenle. Manuel giris VEYA ekran goruntusunden OCR ile doldurma (sonuc onaya sunulur).
struct EarningFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var location
    @Environment(SyncCoordinator.self) private var sync

    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    /// Kayitli kanitlar: ayni ekran goruntusu ikinci kez eklenirse uyarilir.
    @Query private var evidences: [ScreenshotEvidence]

    @State private var viewModel: EarningFormViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var showUnreviewedConfirmation = false
    @State private var saveError: String?
    @State private var showPhotoPicker: Bool
    @State private var appliedInitialImport = false
    @AppStorage(AppPreferences.calibrationOptInKey) private var calibrationOptIn = false
    @State private var isSendingCalibration = false
    /// Bu ekran goruntusu icin son kalibrasyon sonucu; yeni goruntu okununca sifirlanir.
    @State private var calibrationResult: OutboxResult?

    private let session: WorkSessionSummary?
    private let importer: ScreenshotImporter
    private let initialImported: ImportedScreenshot?
    /// Basarili kayittan sonra (kapanmadan once) cagrilir; or. bekleyen vardiyayi listeden dusurmek icin.
    private let onSaved: (() -> Void)?

    /// - Parameters:
    ///   - imported: Paylas eklentisi / otomatik tarama sonucu; form bununla dolu acilir.
    ///   - opensPhotoPicker: "Ekran goruntusu" ile acildiginda secici hemen gosterilir.
    ///   - onSaved: Yalnizca kayit basariliysa cagrilir (vazgecilince cagrilmaz).
    init(
        record: EarningRecord? = nil,
        session: WorkSessionSummary? = nil,
        defaultPlatform: Platform? = nil,
        imported: ImportedScreenshot? = nil,
        opensPhotoPicker: Bool = false,
        importer: ScreenshotImporter = ScreenshotImporter(),
        onSaved: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: EarningFormViewModel(
            record: record, session: session, defaultPlatform: defaultPlatform, imported: imported
        ))
        _showPhotoPicker = State(initialValue: opensPhotoPicker)
        self.session = session
        self.importer = importer
        self.initialImported = imported
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            Form {
                if !vm.isEditing {
                    ocrSection
                }

                if let message = vm.reviewMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                            .accessibilityIdentifier("earningForm.reviewWarning")
                    }
                }

                Section("Vardiya") {
                    Picker("Platform", selection: Binding(
                        get: { vm.platform },
                        set: { vm.platform = $0; vm.markReviewed(.platform) }
                    )) {
                        Text("Seç").tag(Platform?.none)
                        ForEach(platforms) { platform in
                            Text(platform.name).tag(Platform?.some(platform))
                        }
                    }
                    .reviewHighlight(vm.fieldsToReview.contains(.platform))
                    .accessibilityIdentifier("earningForm.platform")

                    DatePicker("Tarih", selection: Binding(
                        get: { vm.date },
                        set: { vm.date = $0; vm.markReviewed(.date) }
                    ), displayedComponents: .date)
                    .environment(\.locale, Formatters.locale)
                    .reviewHighlight(vm.fieldsToReview.contains(.date))

                    DatePicker("Başlangıç", selection: Binding(
                        get: { vm.startTime },
                        set: { vm.startTime = $0; vm.markReviewed(.hours) }
                    ), displayedComponents: .hourAndMinute)
                    .environment(\.locale, Formatters.locale)
                    .reviewHighlight(vm.fieldsToReview.contains(.hours))

                    DatePicker("Bitiş", selection: Binding(
                        get: { vm.endTime },
                        set: { vm.endTime = $0; vm.markReviewed(.hours) }
                    ), displayedComponents: .hourAndMinute)
                    .environment(\.locale, Formatters.locale)
                    .reviewHighlight(vm.fieldsToReview.contains(.hours))

                    let interval = vm.resolvedInterval()
                    LabeledContent("Süre", value: Formatters.duration(interval.end.timeIntervalSince(interval.start)))
                        .foregroundStyle(.secondary)
                }

                Section {
                    AmountField(title: "Kazanç (brüt)", text: Binding(
                        get: { vm.grossText },
                        set: { vm.grossText = $0; vm.markReviewed(.gross) }
                    ), identifier: "earningForm.gross")
                    .reviewHighlight(vm.fieldsToReview.contains(.gross))

                    AmountField(title: "Bonus", text: Binding(
                        get: { vm.bonusText },
                        set: { vm.bonusText = $0; vm.markReviewed(.bonus) }
                    ), identifier: "earningForm.bonus")
                    .reviewHighlight(vm.fieldsToReview.contains(.bonus))

                    AmountField(title: "Paket sayısı", text: Binding(
                        get: { vm.packageText },
                        set: { vm.packageText = $0; vm.markReviewed(.packages) }
                    ), suffix: "", keyboard: .numberPad, identifier: "earningForm.packages")
                    .reviewHighlight(vm.fieldsToReview.contains(.packages))

                    AmountField(title: "Mesafe", text: Binding(
                        get: { vm.distanceText },
                        set: { vm.distanceText = $0; vm.markReviewed(.distance) }
                    ), suffix: "km", identifier: "earningForm.distance")
                } header: {
                    Text("Tutarlar")
                } footer: {
                    if vm.source == .ocr {
                        Text("Ekrandaki toplam bonusu içeriyorsa brüt kazanç = toplam − bonus olarak hesaplandı.")
                    }
                }

                regionSection

                if !vm.validationErrors.isEmpty, !vm.grossText.isEmpty || vm.platform == nil {
                    Section {
                        ForEach(vm.validationErrors, id: \.self) { error in
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                    }
                }
            }
            .dismissesKeyboard()
            .navigationTitle(vm.isEditing ? "Kazancı düzenle" : "Kazanç ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                        .accessibilityIdentifier("form.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { attemptSave() }
                        .disabled(!vm.canSave)
                        .accessibilityIdentifier("form.save")
                }
            }
            .confirmationDialog(
                "Bazı alanlar ekran görüntüsünden kesin okunamadı.",
                isPresented: $showUnreviewedConfirmation,
                titleVisibility: .visible
            ) {
                Button("Kontrol ettim, kaydet") { save() }
                Button("Geri dön", role: .cancel) {}
            } message: {
                Text(vm.reviewMessage ?? "")
            }
            .alert("Kaydedilemedi", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem,
                          matching: .screenshots, photoLibrary: .shared())
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await loadScreenshot(item) }
            }
            .onChange(of: viewModel.imported?.textHash) { _, _ in
                // Yeni ekran goruntusu: kalibrasyon yeniden gonderilebilir
                calibrationResult = nil
            }
            .task {
                // Init'te platform listesi yoktu; platformu eslestirmek icin bir kez yeniden uygulanir
                if let initialImported, !appliedInitialImport {
                    appliedInitialImport = true
                    viewModel.apply(initialImported, platforms: platforms, knownTextHashes: knownHashes)
                }
                await viewModel.resolveRegionIfNeeded(using: location, from: session)
            }
        }
    }

    // MARK: - Bolumler

    private var ocrSection: some View {
        Section {
            PhotosPicker(selection: $photoItem, matching: .screenshots, photoLibrary: .shared()) {
                Label("Ekran görüntüsünden doldur", systemImage: "text.viewfinder")
            }
            .accessibilityIdentifier("earningForm.ocrPicker")

            if viewModel.isDuplicateScreenshot {
                Label("Bu ekran görüntüsü daha önce kaydedilmiş.", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("earningForm.duplicateWarning")
            }

            switch viewModel.ocrState {
            case .idle:
                EmptyView()
            case .processing:
                HStack {
                    ProgressView()
                    Text("Metin okunuyor…").foregroundStyle(.secondary)
                }
            case .finished:
                VerificationBadge(level: viewModel.pendingVerification)
                ForEach(viewModel.assessmentIssues, id: \.self) { issue in
                    Label(issue, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .failed(let message):
                Label(message, systemImage: "xmark.octagon")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }

            if calibrationOptIn, viewModel.imported != nil {
                calibrationRow
            }

            if BuildEnvironment.showsTesterTools, let report = viewModel.ocrDiagnosticReport {
                ShareLink(item: report, subject: Text("Kurye Kazanç OCR raporu")) {
                    Label("Yanlış okuduysa: okunan metni geliştiriciye gönder", systemImage: "ladybug")
                        .font(.subheadline)
                }
                .accessibilityIdentifier("earningForm.ocrReport")
            }
        } footer: {
            Text("Trendyol GO, Getir, Yemeksepeti ve Migros kazanç ekranları tanınır. Görüntü cihazında işlenir; görselin kendisi saklanmaz.")
        }
    }

    /// Kalibrasyon rizasi acik ve form OCR kanitliyken: maskelenmis satirlari gonder.
    @ViewBuilder
    private var calibrationRow: some View {
        Button {
            sendCalibration()
        } label: {
            HStack {
                Label("Kalibrasyona gönder", systemImage: "paperplane")
                if isSendingCalibration {
                    Spacer()
                    ProgressView()
                }
            }
        }
        // Basarili / kuyruga alinmis ornek ikinci kez gonderilmez
        .disabled(isSendingCalibration || (calibrationResult != nil && calibrationResult != .invalid))
        .accessibilityIdentifier("earningForm.calibrate")

        if let calibrationResult {
            Text(calibrationResultText(calibrationResult))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("earningForm.calibrateResult")
        }
    }

    private func calibrationResultText(_ result: OutboxResult) -> String {
        switch result {
        case .ok, .duplicate: "Gönderildi, teşekkürler"
        case .rateLimited: "Bugünlük sınır doldu"
        // Gecici hata: ornek kuyruga alindi, baglanti gelince tekrar gonderilir
        case .transient: "Gönderilemedi, sonra tekrar denenecek"
        case .invalid: "Gönderilemedi"
        }
    }

    private var regionSection: some View {
        @Bindable var vm = viewModel
        return Section {
            TextField("İlçe", text: $vm.district)
            TextField("Semt / mahalle", text: $vm.neighborhood)
            TextField("İl", text: $vm.province)
        } header: {
            HStack {
                Text("Bölge")
                if vm.isResolvingRegion {
                    ProgressView().controlSize(.small)
                }
            }
        } footer: {
            Text("Konumdan otomatik bulunur; yalnızca ilçe/semt kaydedilir, tam konum saklanmaz.")
        }
    }

    // MARK: - Eylemler

    private func loadScreenshot(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            viewModel.ocrState = .failed("Görsel yüklenemedi.")
            return
        }
        let identifier: String? = item.itemIdentifier
        let capturedAt: Date? = PhotoAssetInfo.creationDate(localIdentifier: identifier)
        await viewModel.importScreenshot(
            data: data,
            assetIdentifier: identifier,
            capturedAt: capturedAt,
            importer: importer,
            platforms: platforms,
            knownTextHashes: knownHashes
        )
    }

    private func sendCalibration() {
        guard let imported = viewModel.imported else { return }
        // Veritabanina eklenmeyen gecici kanit: yalnizca gonderim icin (kayitla kaydedilen kanit ayridir)
        let evidence = ScreenshotEvidence(
            capturedAt: imported.capturedAt,
            assetIdentifier: imported.assetIdentifier,
            parsed: imported.parsed,
            lines: imported.lines,
            isGenuineScreenshot: imported.isGenuine
        )
        let coordinator: SyncCoordinator = sync
        isSendingCalibration = true
        Task {
            let result: OutboxResult = await coordinator.sendCalibration(evidence)
            calibrationResult = result
            isSendingCalibration = false
        }
    }

    /// Kayitli kanitlarin metin ozetleri (bos ozet eslesme sayilmaz).
    private var knownHashes: Set<String> {
        let hashes: [String] = evidences.map(\.textHash).filter { !$0.isEmpty }
        return Set(hashes)
    }

    private func attemptSave() {
        if viewModel.fieldsToReview.isEmpty {
            save()
        } else {
            showUnreviewedConfirmation = true
        }
    }

    private func save() {
        do {
            try viewModel.save(in: modelContext)
            onSaved?()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// PhotoKit cekim tarihi. Secicinin verdigi yerel kimlik + fotograf izni (tam / sinirli) gerekir; yoksa nil.
enum PhotoAssetInfo {
    static func creationDate(localIdentifier: String?) -> Date? {
        guard let localIdentifier else { return nil }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return assets.firstObject?.creationDate
    }
}

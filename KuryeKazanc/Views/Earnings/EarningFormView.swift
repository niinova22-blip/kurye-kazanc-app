import SwiftUI
import SwiftData
import PhotosUI

/// Kazanc ekle / duzenle. Manuel giris VEYA ekran goruntusunden OCR ile doldurma (sonuc onaya sunulur).
struct EarningFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var location

    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    @State private var viewModel: EarningFormViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var showUnreviewedConfirmation = false
    @State private var saveError: String?
    @State private var showPhotoPicker: Bool

    private let session: WorkSessionSummary?
    private let importer: ScreenshotImporter
    private let initialImported: ImportedScreenshot?

    /// - Parameters:
    ///   - imported: Paylas eklentisi / otomatik tarama sonucu; form bununla dolu acilir.
    ///   - opensPhotoPicker: "Ekran goruntusu" ile acildiginda secici hemen gosterilir.
    init(
        record: EarningRecord? = nil,
        session: WorkSessionSummary? = nil,
        defaultPlatform: Platform? = nil,
        imported: ImportedScreenshot? = nil,
        opensPhotoPicker: Bool = false,
        importer: ScreenshotImporter = ScreenshotImporter()
    ) {
        _viewModel = State(initialValue: EarningFormViewModel(
            record: record, session: session, defaultPlatform: defaultPlatform, imported: imported
        ))
        _showPhotoPicker = State(initialValue: opensPhotoPicker)
        self.session = session
        self.importer = importer
        self.initialImported = imported
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
            .task {
                if let initialImported, viewModel.platform == nil {
                    viewModel.apply(initialImported, platforms: platforms)
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
        await viewModel.importScreenshot(data: data, assetIdentifier: item.itemIdentifier,
                                         importer: importer, platforms: platforms)
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
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

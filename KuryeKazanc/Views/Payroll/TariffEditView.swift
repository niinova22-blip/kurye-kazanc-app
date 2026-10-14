import SwiftUI
import TipKit

/// Tarife ekranindaki kalem (1.10): firmanin tutarlarini kullanici kendi sozlesmesine gore degistirir.
/// Kaydedince hemen kullanilir ("Kullanıcı girdi" etiketiyle); "Firma değerlerine dön" ile geri alinir.
struct TariffEditView: View {
    @Environment(PayrollModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var texts: [String: String] = [:]
    /// Acilistaki metinler ve daha once duzenlenmis kalemler: yalnizca bunlar kullanici degeri olarak kaydedilir
    /// (aralikli firma tutari, dokunulmadikca tek degere inmesin).
    @State private var initialTexts: [String: String] = [:]
    @State private var previouslyEdited: Set<String> = []
    @State private var loaded = false
    @State private var confirmsReset = false

    private var firm: TariffVersion? { model.firmVersion() }

    private var editableItems: [TariffItem] {
        let today: String = model.today
        return (firm?.items ?? []).filter { item in
            !item.withdrawn && item.unit != .multiplier && (item.effectiveUntil.map { $0 > today } ?? true)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(editableItems) { item in
                        row(item)
                    }
                } header: {
                    Text(PayrollModel.platformName(model.state.activePlatform ?? ""))
                } footer: {
                    Text("Yalnızca farklı olan tutarları değiştir. Kaydettiğin değerler bundan sonraki tüm hesaplarda kullanılır ve “Kullanıcı girdi” olarak gösterilir.")
                }
                if model.hasEditedTariff {
                    Section {
                        Button("Firma değerlerine dön", role: .destructive) { confirmsReset = true }
                            .accessibilityIdentifier("tariffEdit.reset")
                    }
                }
                if let error = model.lastError {
                    Section { Text(error).font(.caption).foregroundStyle(Theme.negative) }
                }
            }
            .navigationTitle("Tutarları düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .dismissesKeyboard()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("tariffEdit.save")
                }
            }
            .confirmationDialog("Kendi değerlerin silinip firmanın tarifesi kullanılacak.", isPresented: $confirmsReset,
                                titleVisibility: .visible) {
                Button("Firma değerlerine dön", role: .destructive) {
                    model.resetToFirmTariff()
                    Haptics.success()
                    dismiss()
                }
                Button("Vazgeç", role: .cancel) {}
            }
            .onAppear(perform: load)
        }
    }

    private func row(_ item: TariffItem) -> some View {
        let changed: Bool = isChanged(item)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).font(.subheadline)
                Text("Firma: \(PayFormat.range(item.amount, item.amountUpper ?? item.amount))\(item.unit.suffix)")
                    .font(.caption2)
                    .foregroundStyle(changed ? Theme.highlight : .secondary)
            }
            Spacer(minLength: 8)
            TextField("Tutar", text: binding(item.key))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 100)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(changed ? Theme.highlight.opacity(0.15) : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier("tariffEdit.\(item.key)")
            Text("₺").foregroundStyle(.secondary)
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { texts[key] ?? "" }, set: { texts[key] = $0 })
    }

    private func isChanged(_ item: TariffItem) -> Bool {
        guard let text = texts[item.key], let amount = PayFormat.parseMoney(text) else { return false }
        return amount != item.amount
    }

    /// Alanlar kullanilan degerle (daha once duzenlendiyse kullanicinin degeri) dolar.
    private func load() {
        guard !loaded else { return }
        loaded = true
        let current: [TariffItem] = model.currentVersion()?.items ?? []
        for item in editableItems {
            let used: TariffItem = current.first { $0.key == item.key } ?? item
            texts[item.key] = Formatters.decimalText(used.amount.value)
            if used.amount != item.amount || used.amountUpper != item.amountUpper { previouslyEdited.insert(item.key) }
        }
        initialTexts = texts
    }

    private func save() {
        var amounts: [String: Money] = [:]
        for item in editableItems {
            guard let text = texts[item.key], let amount = PayFormat.parseMoney(text) else { continue }
            let touched: Bool = text != initialTexts[item.key]
            guard touched || previouslyEdited.contains(item.key) else { continue }
            amounts[item.key] = amount
        }
        guard model.applyTariffEdits(amounts) else { return }
        Haptics.success()
        TariffEditTip().invalidate(reason: .actionPerformed)
        dismiss()
    }
}

/// Tarife ekranlarinin ust cubugundaki kalem dugmesi (fikir balonuyla).
struct TariffEditButton: View {
    /// Liste satirinda yaziyla ("Tutarları düzenle"); ust cubukta yalnizca kalem.
    var title: String? = nil
    @State private var showsEditor = false
    private let tip = TariffEditTip()

    var body: some View {
        Button {
            tip.invalidate(reason: .actionPerformed)
            showsEditor = true
        } label: {
            if let title {
                Label(title, systemImage: "pencil")
            } else {
                Image(systemName: "pencil")
            }
        }
        .accessibilityLabel("Tutarları düzenle")
        .accessibilityIdentifier("tariff.edit")
        .popoverTip(tip)
        .sheet(isPresented: $showsEditor) { TariffEditView() }
    }
}

import SwiftUI

/// Arac ve yakit: guncel fiyat girisi, tuketim, fiyat gecmisi. Fiyat simdilik elle girilir.
struct FuelSettingsView: View {
    @Environment(PayrollModel.self) private var payroll
    @State private var price: Decimal?
    @State private var type: FuelType = .gasoline
    @State private var date = Date()
    @State private var consumption: Decimal = 3
    @State private var loaded = false
    @State private var saved = false

    var body: some View {
        List {
            priceSection
            Section("Tüketim") {
                DecimalStepper(title: "Ortalama", value: $consumption, range: 1...20, step: Decimal(string: "0.5")!,
                               unit: "\(type.unitName)/100 km", identifier: "fuelSettings.consumption")
                    .onChange(of: consumption) { _, value in
                        if loaded { payroll.setConsumption(value) }
                    }
            }
            historySection
        }
        .navigationTitle("Araç ve yakıt")
        .navigationBarTitleDisplayMode(.inline)
        .dismissesKeyboard()
        .saveConfirmation(isPresented: $saved)
        .onAppear(perform: load)
    }

    private var priceSection: some View {
        Section {
            Picker("Yakıt", selection: $type) {
                ForEach(FuelType.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            HeroAmountField(title: "Fiyat (\(type.unitName) başına)", value: $price, identifier: "fuelSettings.price")
            DatePicker("Tarih", selection: $date, in: ...Date(), displayedComponents: .date)
            Button("Fiyatı kaydet", action: savePrice)
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled((price ?? 0) <= 0)
                .opacity((price ?? 0) > 0 ? 1 : 0.5)
                .accessibilityIdentifier("fuelSettings.save")
        } header: {
            Text("Güncel fiyat")
        } footer: {
            Text("Pompadaki fiyatı gir. Fiyat 7 günden eskiyse Bugün ekranında hatırlatılır. İleride fiyatlar otomatik güncellenecek.")
        }
    }

    private var historySection: some View {
        let entries: [FuelPriceEntry] = payroll.state.fuel.entries.reversed()
        return Section("Fiyat geçmişi") {
            if entries.isEmpty {
                Text("Henüz fiyat girilmedi.").foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                LabeledContent(PayFormat.day(entry.day), value: "\(PayFormat.tl(entry.pricePerUnit))/\(entry.type.unitName)")
            }
            .onDelete { offsets in
                for index in offsets { payroll.deleteFuelPrice(entries[index].id) }
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        consumption = payroll.fuelModel(fallbackCostPerKm: 0).consumption
        type = payroll.state.fuel.entries.last?.type ?? .gasoline
        loaded = true
    }

    private func savePrice() {
        guard let price, price > 0 else { return }
        payroll.addFuelPrice(Money(price), type: type, on: date)
        self.price = nil
        withAnimation { saved = true }
    }
}

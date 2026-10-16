import SwiftUI
import SwiftData

/// Arac ve yakit: arac, guncel fiyat girisi, tuketim, fiyat gecmisi. Fiyat simdilik elle girilir.
/// 1.13: arac tek yerde (eskiden Profil'de ayri bir "Araç" vardi ve tarifedeki aracla ayrisabiliyordu).
struct FuelSettingsView: View {
    @Environment(PayrollModel.self) private var payroll
    @Environment(\.modelContext) private var modelContext
    @Query private var couriers: [Courier]
    @State private var vehicle: String = "motorcycle"
    @State private var price: Decimal?
    @State private var type: FuelType = .gasoline
    @State private var date = Date()
    @State private var consumption: Decimal = 3
    @State private var loaded = false
    @State private var saved = false

    var body: some View {
        List {
            vehicleSection
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

    /// Firmanin tarifesi araca gore degisiyorsa onun secenekleri, yoksa motosiklet / otomobil (yakit tuketimi icin).
    private var vehicleOptions: [String] {
        let fromTariff: [String] = payroll.questions(for: payroll.tariffProfile?.platformCode ?? "").vehicleTypes
        return fromTariff.isEmpty ? ["motorcycle", "car"] : fromTariff
    }

    private var vehicleSection: some View {
        Section {
            Picker("Araç", selection: $vehicle) {
                ForEach(vehicleOptions, id: \.self) { Text(TariffQuestions.vehicleName($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("fuelSettings.vehicle")
            .onChange(of: vehicle) { _, value in
                guard loaded, value != payroll.state.vehicleType else { return }
                saveVehicle(value)
            }
        } header: {
            Text("Araç")
        } footer: {
            Text("Araç değişince ortalama tüketim o aracın varsayılanına döner; aşağıdan değiştirebilirsin.")
        }
    }

    private func saveVehicle(_ value: String) {
        payroll.setPreferences(regionTier: payroll.state.regionTier, seniorityYears: payroll.state.seniorityYears,
                               vehicleType: value)
        if let courier = couriers.first, let type = VehicleType(rawValue: value) {
            courier.vehicleType = type
            try? modelContext.save()
        }
        consumption = FuelCostModel.defaultConsumption(vehicleType: value)
        payroll.setConsumption(consumption)
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
            Text("Pompadaki fiyatı gir. Fiyat 7 günden eskiyse Bugün ekranında hatırlatılır.")
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
        vehicle = payroll.state.vehicleType ?? couriers.first?.vehicleType.rawValue ?? "motorcycle"
        if !vehicleOptions.contains(vehicle) { vehicle = vehicleOptions.first ?? "motorcycle" }
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

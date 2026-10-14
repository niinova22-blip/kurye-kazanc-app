import SwiftUI
import SwiftData

/// Gelismis: kurye icin teknik ekranlar (tarife surumleri ve kaynaklari, kendi tarifem, hakedis ayarlari, gider tahmini).
struct AdvancedView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink { TariffInfoView() } label: {
                    Label("Tarife, kaynak ve kendi tarifem", systemImage: "doc.text.magnifyingglass")
                }
                NavigationLink { PayrollSettingsView() } label: {
                    Label("Hakediş ayarları", systemImage: "slider.horizontal.3")
                }
            } footer: {
                Text("Tarifeler resmî kaynaklardan takip edilir; değişiklikler onaydan geçmeden yayımlanmaz.")
            }
            ExpenseEstimateSection()
        }
        .navigationTitle("Gelişmiş")
        .navigationBarTitleDisplayMode(.inline)
        .dismissesKeyboard()
    }
}

/// Gider tahmini: yakit fiyati girilmemisse km basina yedek maliyet (1.10'da Profil'den tasindi).
private struct ExpenseEstimateSection: View {
    @Query private var couriers: [Courier]
    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true
    @State private var costText = ""

    var body: some View {
        Section {
            Toggle("Otomatik gider tahmini", isOn: $autoEstimate)
                .accessibilityIdentifier("settings.autoEstimate")
            HStack {
                Text("Km başına maliyet (yedek)")
                Spacer()
                TextField("0", text: $costText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                    .onChange(of: costText) { _, newValue in
                        if let value = TurkishNumberParser.parseDecimal(newValue), value >= 0 {
                            costPerKm = value
                        }
                    }
                    .accessibilityIdentifier("settings.costPerKm")
                Text("₺").foregroundStyle(.secondary)
            }
            .disabled(!autoEstimate)
            if let courier = couriers.first {
                Button("\(courier.vehicleType.displayName) varsayılanını kullan (\(Formatters.currency(courier.vehicleType.defaultCostPerKm)))") {
                    costPerKm = courier.vehicleType.defaultCostPerKm
                    costText = TurkishNumberParser.format(costPerKm)
                }
                .disabled(!autoEstimate)
            }
        } header: {
            Text("Gider hesaplama")
        } footer: {
            Text("Yakıt fiyatı girdiysen gider km × tüketim × fiyattır; girmediysen km × bu tutar.")
        }
        .onAppear { costText = TurkishNumberParser.format(costPerKm) }
    }
}

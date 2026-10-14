import SwiftUI

/// Biten vardiyanin otomatik hesabi: firmadan alinacak, yakit, cebe kalan ve istenince acilan ayrintili dokum.
struct ShiftSummaryView: View {
    let log: WorkLog
    let onClose: () -> Void

    @Environment(PayrollModel.self) private var payroll
    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm

    private var detail: PayDetail { payroll.detail(for: log.result, days: 1) }

    /// Yakit: kaydin km'si (GPS) × guncel yakit maliyeti.
    private var fuel: Money {
        payroll.fuelModel(fallbackCostPerKm: costPerKm).cost(km: log.input.totalKm ?? log.input.distanceKm, on: log.startDay)
    }

    var body: some View {
        let total: Money = detail.periodTotal
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Vardiya tamamlandı", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(Color(hex: 0x6EE7B7))
                    Text("Cebine kalan")
                        .font(.subheadline)
                        .opacity(0.8)
                    Text(PayFormat.tl(total - fuel))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityIdentifier("shiftSummary.net")
                    Text("Tahmini; firmanın güncel tarifesiyle (\(log.result.tariffVersionLabel)) hesaplandı.")
                        .font(.caption)
                        .opacity(0.75)
                }

                HStack(spacing: 10) {
                    tile("shippingbox.fill", "\(log.input.totalPackages)", "paket")
                    tile("clock.fill", Formatters.duration(log.input.hours.doubleValue * 3600), "süre")
                    tile("road.lanes", Formatters.decimalText(log.input.totalKm ?? log.input.distanceKm), "km")
                }

                VStack(spacing: 10) {
                    money("Firmadan alacağın", PayFormat.tl(total), identifier: "shiftSummary.gross")
                    money("Yakıt gideri", "−" + PayFormat.tl(fuel), identifier: "shiftSummary.fuel")
                    if detail.hasEstimates {
                        Text("Sabit ücretin bu güne düşen payı dahil (ay sonunda ödenir).")
                            .font(.caption)
                            .opacity(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                PayDetailDisclosure(detail: detail, identifier: "shiftSummary.detail")
                    .padding(16)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .tint(.white)

                ForEach(log.result.progress.filter { $0.remaining > 0 }.prefix(2)) { progress in
                    Label("\(progress.label): \(progress.remaining) paket kaldı (\(PayFormat.tl(progress.reward)))",
                          systemImage: "gift.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: 0xFCD34D))
                }

                Text("Kayıt Kazanç ekranına eklendi; Bugün'deki hedef çubuğu da güncellendi.")
                    .font(.footnote)
                    .opacity(0.8)

                Button(action: onClose) {
                    Text("Tamam")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(Theme.accent)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("shiftSummary.done")
            }
            .foregroundStyle(.white)
            .padding(20)
        }
    }

    private func tile(_ symbol: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.title3)
            Text(value).font(.title3.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            Text(unit).font(.caption).opacity(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func money(_ title: String, _ value: String, identifier: String) -> some View {
        HStack {
            Text(title).font(.subheadline).opacity(0.85)
            Spacer()
            Text(value).font(.headline.monospacedDigit()).accessibilityIdentifier(identifier)
        }
    }
}

import SwiftUI

/// Bugun > "Günün ipucu" fikir balonu: hedefe kalan paket ya da firmaya ozel, gune gore degisen kisa bir oneri.
/// Bildirimler kapaliysa ipucu hatirlatmalari acmayi onerir. "Kapat" o gun icin gizler.
struct DailyHintSection: View {
    let firmCode: String?
    let progress: DailyGoalProgress?

    @Environment(PayrollModel.self) private var payroll
    @State private var reminders = ReminderScheduler.shared
    @AppStorage("hint.dismissedDay") private var dismissedDay = ""

    var body: some View {
        if dismissedDay != payroll.today {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.max.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.highlight)
                        .symbolEffect(.bounce, value: dismissedDay)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Günün ipucu")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(hint.text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("today.hint")
                        HStack(spacing: 16) {
                            if hint.offersReminders {
                                Button("Hatırlatmaları aç") {
                                    Task { await reminders.enableRecommended() }
                                }
                                .font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("today.hint.enableReminders")
                            }
                            Button("Kapat") {
                                withAnimation { dismissedDay = payroll.today }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("today.hint.dismiss")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }
            .task { await reminders.refreshStatus() }
        }
    }

    private struct Hint {
        var text: String
        var offersReminders = false
    }

    private var hint: Hint {
        if !reminders.hasAnyScheduled, !reminders.isAuthorized, reminders.status != .denied, dayIndex % 3 == 0 {
            return Hint(text: "Vardiya saatinde ve gün sonunda kısa bir hatırlatma ister misin? Unuttuğun günleri kaçırmazsın.",
                        offersReminders: true)
        }
        if let progress, progress.targetPackages > 0, progress.remainingPackages > 0, progress.packages > 0 {
            return Hint(text: "Bugünkü hedefe \(progress.remainingPackages) paket kaldı. \(firmTip ?? "")")
        }
        let pool: [String] = tips
        return Hint(text: pool[dayIndex % pool.count])
    }

    /// Yilin gunu: ipucu her gun degisir, gun icinde sabit kalir.
    private var dayIndex: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
    }

    private var firmTip: String? {
        switch firmCode {
        case "yemeksepeti": "Akşam bandında (18:00 sonrası) paket ücreti daha yüksek."
        case "pt_restoran": "Günlük paket primi kademeli; bir üst kademe günün kazancını belirgin artırır."
        case "pt_migros", "migros_hemen": "Günlük paket primi kademeli; bir üst kademeye az kaldıysa bir tur daha değer."
        default: nil
        }
    }

    private var tips: [String] {
        var list: [String] = [
            "Vardiyayı başlatmayı unuttuysan “Elle hesapla” ile paket, km ve saati sonradan gir.",
            "Tarifendeki tutar sözleşmenden farklıysa Kazanç > Tarife ekranındaki kalemle kendi değerini yaz.",
            "Yakıt fiyatı değişince Profil > Araç ve yakıt'tan güncelle; net kazancın doğru kalsın.",
            "Hedefini değiştirdiysen “Planı değiştir” ile günlük paket ve saat yeniden hesaplanır.",
            "Apple ile giriş yaparsan kayıtların yedeklenir; telefon değişince kaybolmaz.",
            "Kazanç > Hafta / ay özeti, bir sonraki bonus kademesine kaç paket kaldığını gösterir.",
        ]
        switch firmCode {
        case "yemeksepeti":
            list.append("Yemeksepeti'nde haftalık bonus paket sayına göre artar; hafta sonuna doğru Kazanç'tan kalan paketi kontrol et.")
            list.append("Aynı saati akşama kaydırmak Yemeksepeti'nde paket başı ücreti artırır.")
        case "pt_restoran", "pt_migros", "migros_hemen":
            list.append("Paket Taxi'de sabit ücretin aylık; çalıştığın her güne düşen payı Bugün'de ayrıca gösterilir.")
        default:
            break
        }
        return list
    }
}

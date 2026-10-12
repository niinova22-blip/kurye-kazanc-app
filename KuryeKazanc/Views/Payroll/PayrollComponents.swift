import SwiftUI

/// Hakedis ekranlarinin ortak parcalari. Kural: dogrulanmis tarife verisi, kullanici girisi ve dogrulama gerekli veri
/// her yerde ayni simge + renkle ayrilir.
enum PayFormat {
    static func tl(_ money: Money) -> String { Formatters.currency(money.doubleValue) }

    static func range(_ low: Money, _ high: Money) -> String {
        if low == high { return tl(low) }
        let a: Money = low < high ? low : high
        let b: Money = low < high ? high : low
        return "\(tl(a)) – \(tl(b))"
    }

    static func number(_ value: Decimal) -> String {
        value.doubleValue.formatted(.number.locale(Formatters.locale).precision(.fractionLength(0...2)))
    }

    /// "2026-10-07" -> "7 Ekim 2026"
    static func day(_ text: String) -> String { TariffNotifier.longDate(text) }

    static func parseMoney(_ text: String) -> Money? {
        let trimmed: String = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        return Money(text: trimmed)
    }

    static func parseDecimal(_ text: String) -> Decimal? {
        let trimmed: String = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        return Decimal.parse(trimmed)
    }

    static func parseInt(_ text: String) -> Int {
        Int(text.trimmingCharacters(in: .whitespaces)) ?? 0
    }
}

/// Guven etiketi: Dogrulanmis / Kullanici tarafindan girildi / Dogrulama gerekli.
struct ConfidenceLabel: View {
    let status: ConfidenceStatus
    var compact: Bool = false

    /// 1.7: "Dogrulama gerekli" satir satir gosterilmez; sayfanin altindaki tek `VerificationFootnote` toplar.
    var body: some View {
        if status != .needsVerification {
            Label(compact ? shortName : status.displayName, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(color)
                .accessibilityIdentifier("confidence.\(status.rawValue)")
        }
    }

    private var shortName: String {
        switch status {
        case .verified: "Doğrulanmış"
        case .userEntered: "Senin girişin"
        case .needsVerification: "Doğrulama gerekli"
        }
    }

    private var symbol: String {
        switch status {
        case .verified: "checkmark.seal.fill"
        case .userEntered: "person.crop.circle"
        case .needsVerification: "exclamationmark.triangle"
        }
    }

    private var color: Color {
        switch status {
        case .verified: Theme.accent
        case .userEntered: Color.blue
        case .needsVerification: Color.orange
        }
    }
}

/// Platform simgesi: dogrulanmis logo varligi yoksa notr bas harfler (resmi ortaklik iddiasi yok).
struct PlatformMonogram: View {
    let platform: PayPlatform
    var size: CGFloat = 44

    var body: some View {
        Text(platform.monogram)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.accent)
            .frame(width: size, height: size)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

/// Pano karti: buyuk deger + baslik.
struct PayMetricTile: View {
    let title: String
    let value: String
    var caption: String? = nil
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier(identifier)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

/// Hesaplama satiri.
struct PayLineRow: View {
    let line: PayLine

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(line.label)
                    .font(.subheadline)
                    .strikethrough(!line.included && line.isCash)
                Spacer()
                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(line.included ? Color.primary : Color.secondary)
            }
            HStack(spacing: 8) {
                if let detail { Text(detail).font(.caption2).foregroundStyle(.secondary) }
                ConfidenceLabel(status: line.confidence, compact: true)
            }
            if let note = line.note {
                Text(note).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var amountText: String {
        let range: (Money, Money) = line.displayRange
        let text: String = PayFormat.range(range.0, range.1)
        return line.type == .deduction ? "−\(text)" : text
    }

    private var detail: String? {
        guard let quantity = line.quantity, let rate = line.rate else { return nil }
        let unit: String = line.unit?.suffix ?? ""
        return "\(PayFormat.number(quantity)) × \(PayFormat.tl(rate))\(unit)"
    }
}

/// Hesaplama sonucunun tamami: kalemler, toplamlar, uyarilar, yan haklar.
struct BreakdownSections: View {
    let breakdown: PayBreakdown

    var body: some View {
        Section {
            ForEach(Array(breakdown.lines.enumerated()), id: \.offset) { _, line in
                PayLineRow(line: line)
            }
            totalRow("Brüt hakediş", PayFormat.range(breakdown.gross, breakdown.grossUpper), identifier: "breakdown.gross")
            if !breakdown.tips.isZero || !breakdown.extraPayments.isZero || !breakdown.totalDeductions.isZero || !breakdown.advances.isZero {
                totalRow("Ödeme öncesi tutar", PayFormat.range(breakdown.prePayment, breakdown.prePaymentUpper), identifier: "breakdown.prePayment")
            }
        } header: {
            Text("Hesaplama")
        } footer: {
            Text("Tarife \(breakdown.tariffVersionLabel) · \(originText)")
        }

        let notices: [PayNotice] = breakdown.notices.filter { $0.kind != .needsVerification }
        if !notices.isEmpty {
            Section("Kontrol edilmesi gerekenler") {
                ForEach(Array(notices.enumerated()), id: \.offset) { _, notice in
                    NoticeRow(notice: notice)
                }
            }
        }

        if !breakdown.progress.isEmpty {
            Section("Bonus hedefleri") {
                ForEach(Array(breakdown.progress.enumerated()), id: \.offset) { _, progress in
                    BonusProgressRow(progress: progress)
                }
            }
        }

        if !breakdown.sideBenefits.isEmpty {
            Section {
                ForEach(Array(breakdown.sideBenefits.enumerated()), id: \.offset) { _, line in
                    PayLineRow(line: line)
                }
            } header: {
                Text("Yan haklar ve destekler")
            } footer: {
                Text("Nakit hakedişe eklenmez.")
            }
        }
    }

    private var originText: String {
        switch breakdown.tariffOrigin {
        case .bundled: "başlangıç / örnek kayıt"
        case .remote: "yayımlanan tarife"
        case .user: "kendi tarifen"
        }
    }

    private func totalRow(_ title: String, _ value: String, identifier: String) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .accessibilityIdentifier(identifier)
        }
    }
}

struct NoticeRow: View {
    let notice: PayNotice

    var body: some View {
        Label {
            Text(notice.message).font(.caption)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
    }

    private var symbol: String {
        switch notice.kind {
        case .needsVerification: "exclamationmark.triangle"
        case .ambiguity: "arrow.triangle.branch"
        case .estimate: "wand.and.stars"
        case .deferred: "calendar.badge.clock"
        case .missing: "questionmark.circle"
        case .info: "info.circle"
        }
    }

    private var color: Color {
        switch notice.kind {
        case .needsVerification, .ambiguity: Color.orange
        case .missing: Theme.negative
        default: Color.secondary
        }
    }
}

struct BonusProgressRow: View {
    let progress: BonusProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(progress.label).font(.subheadline)
                Spacer()
                Text("\(progress.current) / \(progress.target)").font(.caption).monospacedDigit()
            }
            ProgressView(value: progress.fraction)
                .tint(Theme.accent)
            HStack {
                Text(progress.remaining > 0 ? "\(progress.remaining) paket kaldı" : "Hedefe ulaşıldı")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                ConfidenceLabel(status: progress.confidence, compact: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Sayisal metin alani (Turkce virgul kabul).
struct NumberField: View {
    let title: String
    @Binding var text: String
    var decimal: Bool = false
    var identifier: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                .accessibilityIdentifier(identifier)
        }
    }
}

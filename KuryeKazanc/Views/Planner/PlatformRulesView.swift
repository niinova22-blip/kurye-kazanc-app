import SwiftUI

/// Platform kurallari: kategori, durum, guven, kaynak ve kontrol tarihi. Kullanici her kosulu kendi
/// sozlesmesine gore onaylayabilir ya da "bende gecerli degil" diyebilir.
struct PlatformRulesView: View {
    let model: PlannerViewModel

    private var today: String {
        RuleDay.string(.now, calendar: .current)
    }

    private struct Group: Identifiable {
        let code: String
        let rules: [PlatformRule]
        var id: String { code }
    }

    private var groups: [Group] {
        let latest: [PlatformRule] = model.ruleSet.latest
        let codes: [String] = Array(Set(latest.map(\.platformCode))).sorted { a, b in
            if a == "*" { return false }
            if b == "*" { return true }
            return a < b
        }
        return codes.map { code in
            let rules: [PlatformRule] = latest.filter { $0.platformCode == code }
            return Group(code: code, rules: rules.sorted { $0.category.displayName < $1.category.displayName })
        }
    }

    var body: some View {
        List {
            Section {
                Text("Kurallar kaynaklı ve tarihlidir. Resmî kaynağı olmayanlar ve 90 günden uzun süredir kontrol edilmeyenler kesin sayılmaz. Kendi sözleşmen, uygulamadaki slot ekranları ve destek yanıtların en güvenilir kaynaktır.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(groups) { group in
                Section(group.code == "*" ? "Tüm platformlar" : model.name(group.code)) {
                    ForEach(group.rules) { rule in
                        RuleRow(model: model, rule: rule, today: today)
                    }
                }
            }
        }
        .navigationTitle("Platform kuralları")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RuleRow: View {
    let model: PlannerViewModel
    let rule: PlatformRule
    let today: String

    private var decision: RuleConfirmation? { model.profile.ruleConfirmations[rule.id] }

    private var statusText: String {
        if rule.kind == .unknownTerm { return "Bilinmeyen koşul" }
        return rule.effectiveStatus(today: today).displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rule.category.displayName).font(.caption.weight(.semibold))
            Text(rule.description).font(.subheadline)
            HStack(spacing: 8) {
                Text(statusText)
                Text("Güven %\(Int((rule.confidence * 100).rounded()))")
                Text("Kontrol: \(rule.lastCheckedOn)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            if let url = rule.sourceURL.flatMap(URL.init(string:)) {
                Link(rule.sourceKind == .official ? "Resmî kaynak" : "Kaynak", destination: url).font(.caption2)
            }
            HStack {
                choice("Sözleşmemde var", .applies)
                choice("Bende geçerli değil", .notApplicable)
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }

    private func choice(_ title: String, _ value: RuleConfirmation) -> some View {
        Button {
            model.setConfirmation(decision == value ? nil : value, ruleID: rule.id)
        } label: {
            Label(title, systemImage: decision == value ? "checkmark.circle.fill" : "circle")
        }
        .buttonStyle(.borderless)
    }
}

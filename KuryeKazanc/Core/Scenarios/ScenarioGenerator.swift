import Foundation

/// Temel duzenler x cesitlemeler (spec 1.4a §4.1). Sabit tohum: her calistirmada ayni senaryolar.
struct ScenarioGenerator {
    var seed: UInt64 = 20261009

    /// SplitMix64: platformdan bagimsiz, tekrarlanabilir.
    private struct Random {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func int(_ range: ClosedRange<Int>) -> Int {
            range.lowerBound + Int(next() % UInt64(range.count))
        }
    }

    enum AmountFormat: CaseIterable { case trailing, leading, tl }

    static func format(_ value: Double, _ format: AmountFormat) -> String {
        let cents = Int((value * 100).rounded())
        let whole = cents / 100
        let fraction = cents % 100
        var digits = String(whole)
        var grouped = ""
        while digits.count > 3 {
            grouped = "." + String(digits.suffix(3)) + grouped
            digits = String(digits.dropLast(3))
        }
        let number = digits + grouped + "," + String(format: "%02d", fraction)
        switch format {
        case .trailing: return "\(number) ₺"
        case .leading: return "₺\(number)"
        case .tl: return "\(number) TL"
        }
    }

    private struct Base {
        var templateID: String
        var platformCode: String
        var make: (inout Random, AmountFormat) -> (header: [String], rows: [ScenarioRow], footer: [String], expected: ScenarioExpectation)
    }

    private var bases: [Base] {
        [
            Base(templateID: "trendyol_go.earnings", platformCode: "trendyol_go") { rng, f in
                let total = Double(rng.int(80_000...400_000)) / 100
                let bonus = Double(rng.int(0...20)) * 10
                let packages = rng.int(5...40)
                return (["Trendyol GO", "Kazançlarım", "Bugün"],
                        [ScenarioRow(label: "Toplam Kazanç", value: Self.format(total, f)),
                         ScenarioRow(label: "Teslimat Sayısı", value: "\(packages)"),
                         ScenarioRow(label: "Bonus", value: Self.format(bonus, f))],
                        [], ScenarioExpectation(templateID: "trendyol_go.earnings", total: total, bonus: bonus,
                                                packages: packages, duration: nil, period: .day))
            },
            Base(templateID: "getir.earnings", platformCode: "getir") { rng, f in
                let total = Double(rng.int(60_000...350_000)) / 100
                let bonus = Double(rng.int(0...15)) * 10
                let packages = rng.int(5...35)
                return (["Getir", "Kazançlarım", "Bugün"],
                        [ScenarioRow(label: "Toplam Kazanç", value: Self.format(total, f)),
                         ScenarioRow(label: "Sipariş Sayısı", value: "\(packages)"),
                         ScenarioRow(label: "Ek Kazanç", value: Self.format(bonus, f))],
                        [], ScenarioExpectation(templateID: "getir.earnings", total: total, bonus: bonus,
                                                packages: packages, duration: nil, period: .day))
            },
            Base(templateID: "yemeksepeti.earnings", platformCode: "yemeksepeti") { rng, f in
                let total = Double(rng.int(50_000...300_000)) / 100
                let tip = Double(rng.int(0...10)) * 10
                let packages = rng.int(5...30)
                return (["Yemeksepeti", "Ödemeler", "Bugün"],
                        [ScenarioRow(label: "Toplam Kazanç", value: Self.format(total, f)),
                         ScenarioRow(label: "Sipariş Sayısı", value: "\(packages)"),
                         ScenarioRow(label: "Bahşiş", value: Self.format(tip, f))],
                        [], ScenarioExpectation(templateID: "yemeksepeti.earnings", total: total, bonus: tip,
                                                packages: packages, duration: nil, period: .day))
            },
            Base(templateID: "migros_hemen.earnings", platformCode: "migros_hemen") { rng, f in
                let total = Double(rng.int(300_000...1_500_000)) / 100
                let bonus = Double(rng.int(0...30)) * 10
                let packages = rng.int(30...150)
                return (["Migros Hemen", "Kazançlarım", "Bu Hafta"],
                        [ScenarioRow(label: "Toplam Kazanç", value: Self.format(total, f)),
                         ScenarioRow(label: "Teslimat Sayısı", value: "\(packages)"),
                         ScenarioRow(label: "Prim", value: Self.format(bonus, f))],
                        [], ScenarioExpectation(templateID: "migros_hemen.earnings", total: total, bonus: bonus,
                                                packages: packages, duration: nil, period: .week))
            },
            Base(templateID: "uber.earnings", platformCode: "uber") { rng, f in
                let total = Double(rng.int(300_000...1_500_000)) / 100
                let packages = rng.int(30...120)
                let hours = rng.int(10...60)
                let minutes = rng.int(0...59)
                return (["Kazançlar", "4 Şub - 10 Şub"],
                        [ScenarioRow(label: "", value: Self.format(total, f), splittable: false),
                         ScenarioRow(label: "Çevrimiçi", value: "\(hours) sa \(minutes) dk"),
                         ScenarioRow(label: "Teslimat", value: "\(packages)", valueFirst: true),
                         ScenarioRow(label: "Puan", value: "\(rng.int(10...99))", valueFirst: true, splittable: false)],
                        ["Ayrıntıları gör", "Bakiye: " + Self.format(Double(rng.int(1_000...50_000)) / 100, f)],
                        ScenarioExpectation(templateID: "uber.earnings", total: total, bonus: nil, packages: packages,
                                            duration: TimeInterval(hours * 3600 + minutes * 60), period: .week))
            },
            Base(templateID: "thekurye.invoices", platformCode: "thekurye") { rng, f in
                let count = rng.int(2...6)
                var rows: [ScenarioRow] = []
                var sum = 0.0
                for _ in 0..<count {
                    let fee = Double(rng.int(5_000...40_000)) / 100
                    sum += fee
                    rows.append(ScenarioRow(label: "Taşıma Ücreti", value: Self.format(fee, f), splittable: false))
                    rows.append(ScenarioRow(label: "", value: "#\(rng.int(100...9999))", splittable: false))
                }
                return (["The Kurye", "Faturalar \(count)"], rows, ["Tümünü Seç", "Fatura Oluştur"],
                        ScenarioExpectation(templateID: "thekurye.invoices", total: (sum * 100).rounded() / 100,
                                            bonus: nil, packages: count, duration: nil, period: nil))
            },
            Base(templateID: "yemeksepeti.order", platformCode: "yemeksepeti") { rng, f in
                let extra = Double(rng.int(0...6_000)) / 100
                let total = extra + Double(rng.int(4_000...20_000)) / 100
                return (["Kabul oranı %\(rng.int(60...99))", "Reddet"],
                        [ScenarioRow(label: "", value: Self.format(total, f), splittable: false),
                         ScenarioRow(label: "ek dahil", value: Self.format(extra, f), valueFirst: true, splittable: false)],
                        ["Teslim al 1,6 km - 12 dk", "Kabul et"],
                        ScenarioExpectation(templateID: "yemeksepeti.order", total: total, bonus: extra, packages: 1,
                                            duration: nil, period: .order))
            },
            Base(templateID: "banabikurye.order", platformCode: "banabikurye") { rng, _ in
                let total = Double(rng.int(50...900))
                return (["Sipariş №\(rng.int(10_000...99_999)) Bugün", "Tanım Tarif Chat Ödeme"],
                        [ScenarioRow(label: "Nakit kazanç", value: "\(Int(total))")],
                        ["Gönderi Notu"],
                        ScenarioExpectation(templateID: "banabikurye.order", total: total, bonus: nil, packages: 1,
                                            duration: nil, period: .order))
            },
        ]
    }

    func all() -> [ScreenScenario] {
        var rng = Random(state: seed)
        var result: [ScreenScenario] = []
        var index = 0
        for base in bases {
            for style in ScreenScenario.TextStyle.allCases {
                for split in [false, true] {
                    for format in AmountFormat.allCases {
                        let made = base.make(&rng, format)
                        let theme = ScreenScenario.Theme.allCases[index % 2]
                        let device = ScreenScenario.Device.allCases[index % 3]
                        result.append(ScreenScenario(
                            id: "\(base.templateID)-\(style.rawValue)-\(split ? "split" : "inline")-\(format)",
                            templateID: base.templateID, platformCode: base.platformCode,
                            header: made.header, rows: made.rows, footer: made.footer,
                            theme: theme, device: device, textStyle: style, splitRows: split,
                            noise: index % 2 == 0, expected: made.expected
                        ))
                        index += 1
                    }
                }
            }
        }
        return result
    }
}

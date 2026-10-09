import SwiftUI
import UIKit

/// Senaryodan taklit kazanc ekrani (spec 1.4a §4.3). Testlerde goruntuye cevrilir; TestFlight'ta "Deneme ekranlari".
struct MockEarningsScreen: View {
    let scenario: ScreenScenario

    private var accent: Color {
        switch scenario.platformCode {
        case "trendyol_go": .orange
        case "getir": .purple
        case "yemeksepeti": .red
        case "migros_hemen": Color(red: 1, green: 0.5, blue: 0)
        case "uber": .black
        case "thekurye": .cyan
        case "banabikurye": .green
        default: .gray
        }
    }

    private var background: Color { scenario.theme == .dark ? .black : .white }
    private var foreground: Color { scenario.theme == .dark ? .white : .black }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if scenario.noise {
                HStack { Text(ScreenScenario.topNoise[0]); Spacer(); Text(ScreenScenario.topNoise[1]) }
                    .font(.footnote)
            }
            ForEach(Array(scenario.header.enumerated()), id: \.offset) { index, line in
                Text(scenario.styled(line))
                    .font(index == 0 ? .title2.bold() : .headline)
                    .foregroundStyle(index == 0 ? accent : foreground)
            }
            ForEach(Array(scenario.rows.enumerated()), id: \.offset) { _, row in
                rowView(row)
            }
            ForEach(Array(scenario.footer.enumerated()), id: \.offset) { _, line in
                Text(scenario.styled(line)).font(.subheadline)
            }
            Spacer()
            if scenario.noise {
                HStack { Text(ScreenScenario.bottomNoise[0]); Spacer(); Text(ScreenScenario.bottomNoise[1]) }
                    .font(.footnote)
            }
        }
        .padding(20)
        .foregroundStyle(foreground)
        .frame(width: scenario.device.points.width, height: scenario.device.points.height, alignment: .topLeading)
        .background(background)
    }

    @ViewBuilder
    private func rowView(_ row: ScenarioRow) -> some View {
        let label = scenario.styled(row.label)
        if row.label.isEmpty {
            Text(row.value).font(.largeTitle.bold())
        } else if scenario.splitRows && row.splittable {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.valueFirst ? row.value : label).font(row.valueFirst ? .title3.bold() : .subheadline)
                Text(row.valueFirst ? label : row.value).font(row.valueFirst ? .subheadline : .title3.bold())
            }
        } else {
            HStack {
                Text(row.valueFirst ? row.value : label)
                Spacer()
                Text(row.valueFirst ? label : row.value).bold()
            }
            .font(.body)
            .padding(10)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @MainActor
    static func render(_ scenario: ScreenScenario) -> UIImage {
        let renderer = ImageRenderer(content: MockEarningsScreen(scenario: scenario))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

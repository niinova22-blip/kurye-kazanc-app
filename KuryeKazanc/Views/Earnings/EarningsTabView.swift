import SwiftUI

/// Kazanc sekmesi: hakedis (firmanin tarifesiyle) ve analiz (kayitlardan) tek yerde.
struct EarningsTabView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case payroll = "Hakediş"
        case analysis = "Analiz"
        var id: String { rawValue }
    }

    @Environment(\.showIntro) private var showIntro
    @State private var mode: Mode = .payroll
    @State private var showsHelp = false

    var body: some View {
        NavigationStack {
            content
                .safeAreaInset(edge: .top, spacing: 0) { modePicker }
                .navigationTitle("Kazanç")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { HelpBubble(screen: .earnings, showsScreenHelp: $showsHelp, showIntro: showIntro) }
                .sheet(isPresented: $showsHelp) { ScreenHelpSheet(screen: .earnings) }
        }
    }

    @ViewBuilder private var content: some View {
        switch mode {
        case .payroll: PayrollDashboardView()
        case .analysis: AnalysisView()
        }
    }

    private var modePicker: some View {
        Picker("Görünüm", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .accessibilityIdentifier("earnings.mode")
    }
}

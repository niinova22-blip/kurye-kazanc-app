import SwiftUI
import SwiftData

/// Suren vardiya: tum ekran marka renginde, her teslimde ekrana dokunulur. Her dokunusta paketin tarifedeki bandi
/// ("4–6 km bandı · 1 paket eklendi") gosterilir. "Vardiyayı bitir" hesabi yapip kaydeder ve ozeti acar.
struct LiveShiftView: View {
    @Environment(LiveShiftController.self) private var controller
    @Environment(PayrollModel.self) private var payroll
    @Environment(LocationService.self) private var location
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Kaydedilen vardiya; ozet ayni ekranda gosterilir.
    @State private var finished: WorkLog?
    @State private var confirmsFinish = false
    @State private var showsTutorial = false
    @State private var bounce = 0
    @State private var ripples: [UUID] = []

    var body: some View {
        ZStack {
            AnimatedBrandBackground()
            if let finished {
                ShiftSummaryView(log: finished) { dismiss() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                tracker
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showsTutorial) {
            ShiftTutorialView(mode: .replay) { showsTutorial = false }
        }
        .confirmationDialog("Vardiyayı bitir", isPresented: $confirmsFinish, titleVisibility: .visible) {
            if controller.packageCount > 0 {
                Button("Bitir ve hesapla") { finish() }
                    .accessibilityIdentifier("shift.confirmFinish")
            } else {
                Button("Paket yok, kapat", role: .destructive) {
                    controller.discard()
                    dismiss()
                }
            }
            Button("Devam et", role: .cancel) {}
        } message: {
            Text(controller.packageCount > 0
                 ? "\(controller.packageCount) paket kaydedildi. Hesap firmanın güncel tarifesiyle yapılıp Kazanç'a eklenecek."
                 : "Bu vardiyada paket yok; kayıt yapılmayacak.")
        }
    }

    // MARK: - Takip ekrani

    private var tracker: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
            regionBanner
                .padding(.horizontal, 16)
            Spacer(minLength: 8)
            tapTarget
            Spacer(minLength: 8)
            feedbackCard
                .padding(.horizontal, 16)
                .frame(minHeight: 84)
            estimateStrip
                .padding(.horizontal, 16)
                .padding(.top, 12)
            bottomBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .foregroundStyle(.white)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Küçült")
            .accessibilityIdentifier("shift.minimize")
            Spacer()
            if let start = controller.shift?.start {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Formatters.duration(context.date.timeIntervalSince(start)))
                        .font(.headline.monospacedDigit())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.15), in: Capsule())
                }
            }
            Text(location.isAuthorized ? Formatters.distance(controller.liveDistanceKm) : "Konum kapalı")
                .font(.headline.monospacedDigit())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.15), in: Capsule())
            Spacer()
            Button { showsTutorial = true } label: {
                Image(systemName: "questionmark")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Tanıtımı izle")
            .accessibilityIdentifier("shift.tutorial")
        }
    }

    @ViewBuilder
    private var regionBanner: some View {
        if controller.needsRegionChoice {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hangi bölgede çalışıyorsun?")
                    .font(.subheadline.weight(.semibold))
                Text("Semtin konumdan okunamadı; prim ve sabit ücret bölgeye göre değişir.")
                    .font(.caption)
                    .opacity(0.8)
                HStack {
                    ForEach(controller.regionChoices, id: \.self) { tier in
                        Button(TariffQuestions.regionName(tier)) { controller.chooseRegion(tier) }
                            .accessibilityIdentifier("shift.region.\(tier)")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 10)
        } else if let message = controller.regionMessage {
            Label(message, systemImage: "mappin.and.ellipse")
                .font(.footnote.weight(.semibold))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 10)
                .accessibilityIdentifier("shift.region")
        }
    }

    /// Dev dokunma alani: paket birakilinca dokunulur.
    private var tapTarget: some View {
        Button(action: tap) {
            ZStack {
                ForEach(ripples, id: \.self) { id in
                    RippleRing().id(id)
                }
                Circle()
                    .fill(.white.opacity(0.16))
                    .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: 2))
                Circle()
                    .fill(.white)
                    .padding(26)
                    .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
                VStack(spacing: 2) {
                    Text("\(controller.packageCount)")
                        .font(.system(size: 84, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(controller.packageCount)))
                        .accessibilityIdentifier("shift.count")
                    Text(controller.packageCount == 0 ? "Paketi bırakınca dokun" : "paket · dokun, ekle")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.accent)
            }
            .frame(width: 270, height: 270)
            .scaleEffect(bounce % 2 == 0 ? 1 : 0.94)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.5), value: bounce)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Paket teslim edildi, ekle. Şu ana kadar \(controller.packageCount) paket")
        .accessibilityIdentifier("shift.tap")
    }

    @ViewBuilder
    private var feedbackCard: some View {
        if let feedback = controller.lastFeedback {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(Theme.mintOnDark)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(feedback.zone.title) · 1 paket eklendi")
                        .font(.headline)
                        .accessibilityIdentifier("shift.zone")
                    Text(feedback.zone.detail)
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                Button {
                    Haptics.light()
                    withAnimation(.snappy) { controller.undoLast() }
                } label: {
                    Label("Geri al", systemImage: "arrow.uturn.backward")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                .accessibilityIdentifier("shift.undo")
            }
            .padding(14)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .id(feedback.id)
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
        } else {
            Text("Her teslimde bir kez dokun. Saat ve konum paketle birlikte kaydedilir.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .opacity(0.8)
        }
    }

    private var estimateStrip: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let estimate: Money? = controller.liveShiftGross()
            let fixed: Money = payroll.fixedShareToday()
            VStack(spacing: 8) {
                HStack {
                    stat(fixed.isZero ? "Şu ana kadar (brüt)" : "Şu ana kadar (sabit pay dahil)",
                         estimate.map { PayFormat.tl($0 + fixed) } ?? "—", identifier: "shift.estimate")
                    Divider().frame(height: 30).overlay(.white.opacity(0.4))
                    stat("Bu vardiya", "\(controller.packageCount) paket", identifier: "shift.packages")
                }
                if let day = payroll.bonusTracks(live: controller.packagesByDay()).first(where: { $0.scope == .day }) {
                    Text(dayLine(day))
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .opacity(0.9)
                        .accessibilityIdentifier("shift.dayTotal")
                }
                if payroll.hasFixedPay {
                    FixedPayToggle()
                }
            }
            .padding(12)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// "Bugün 25 paket · 24–27 primi 760 TL · 28. pakete 3 kaldı → 1.005 TL"
    private func dayLine(_ track: BonusTrack) -> String {
        var parts: [String] = ["Bugün toplam \(track.packages) paket"]
        if !track.reached.isZero { parts.append("prim \(PayFormat.tl(track.reached))") }
        if let next = track.next { parts.append("\(next.target). pakete \(next.remaining) kaldı → \(PayFormat.tl(next.reward))") }
        return parts.joined(separator: " · ")
    }

    private func stat(_ title: String, _ value: String, identifier: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).opacity(0.8)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomBar: some View {
        Button {
            Haptics.impact()
            confirmsFinish = true
        } label: {
            Label("Vardiyayı bitir", systemImage: "flag.checkered")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(Theme.negative)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("shift.finish")
    }

    // MARK: - Eylemler

    private func tap() {
        guard controller.recordDelivery() != nil else { return }
        Haptics.impact()
        AppSounds.package()
        bounce += 1
        if !reduceMotion {
            let id = UUID()
            ripples.append(id)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                ripples.removeAll { $0 == id }
            }
        }
    }

    private func finish() {
        let log: WorkLog? = controller.finish(context: modelContext)
        Haptics.success()
        AppSounds.saved()
        if let log {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { finished = log }
        } else {
            dismiss()
        }
    }
}

/// Dokunusta yayilan halka.
private struct RippleRing: View {
    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(.white.opacity(expanded ? 0 : 0.7), lineWidth: 3)
            .scaleEffect(expanded ? 1.35 : 0.8)
            .onAppear { withAnimation(.easeOut(duration: 0.8)) { expanded = true } }
            .allowsHitTesting(false)
    }
}

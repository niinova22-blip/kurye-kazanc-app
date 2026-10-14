import SwiftUI
import TipKit

/// Bugun: aylik hedeften gunluk pay ve gerceklesen. Altinda acikca gorunen "Plan oluştur / Planı değiştir" dugmesi;
/// plan bir kez yapildiktan sonra da buradan degistirilebildigi anlasilsin (1.10).
struct TodayGoalCard: View {
    let progress: DailyGoalProgress?
    let hasGoal: Bool

    private let planTip = PlanTip()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                GoalRing(progress: GoalProgress(target: 1, achieved: progress?.fraction ?? 0), lineWidth: 9)
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)
                summary
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("today.goalCard")
            TipView(planTip, arrowEdge: .bottom)
            NavigationLink {
                GoalPlanView()
                    .onAppear { planTip.invalidate(reason: .actionPerformed) }
            } label: {
                Label(hasGoal ? "Planı değiştir" : "Plan oluştur",
                      systemImage: hasGoal ? "slider.horizontal.3" : "calendar.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("today.planButton")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bugünün hedefi")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let progress, progress.targetPackages == 0 {
                Text("Sabit ücretle zaten karşılanıyor")
                    .font(.subheadline.weight(.semibold))
                Text("Bugün \(progress.packages) paket · \(PayFormat.tl(progress.net)) net")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if let progress {
                Text("\(progress.packages) / \(progress.targetPackages) paket")
                    .font(.headline)
                    .monospacedDigit()
                Text("\(PayFormat.tl(progress.net)) net · hedef ~\(Formatters.decimalText(progress.targetHours)) sa")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text(hasGoal ? "Plan hesaplanamadı" : "Henüz hedef yok")
                    .font(.subheadline.weight(.semibold))
                Text("Hedefine göre günde kaç paket ve kaç saat gerektiğini gör.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

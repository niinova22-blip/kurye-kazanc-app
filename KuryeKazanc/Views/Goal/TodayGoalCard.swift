import SwiftUI

/// Bugun: aylik hedeften gunluk pay ve gerceklesen. Dokununca Plan acilir.
struct TodayGoalCard: View {
    let progress: DailyGoalProgress?
    let hasGoal: Bool

    var body: some View {
        NavigationLink {
            GoalPlanView()
        } label: {
            HStack(spacing: 16) {
                GoalRing(progress: GoalProgress(target: 1, achieved: progress?.fraction ?? 0), lineWidth: 9)
                    .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 4) {
                    if let progress, progress.targetPackages == 0 {
                        Text("Hedefin sabit ücretle zaten karşılanıyor")
                            .font(.subheadline.weight(.semibold))
                        Text("Bugün \(progress.packages) paket, \(PayFormat.tl(progress.net)) net")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else if let progress {
                        Text("Bugün hedef: \(progress.targetPackages) paket · ~\(Formatters.decimalText(progress.targetHours)) sa")
                            .font(.subheadline.weight(.semibold))
                        Text("Şu ana kadar \(progress.packages) paket, \(PayFormat.tl(progress.net)) net")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        Text(hasGoal ? "Plan hesaplanamadı" : "Hedef koy")
                            .font(.subheadline.weight(.semibold))
                        Text("Hedefine göre günde kaç paket ve kaç saat gerektiğini gör.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("today.goalCard")
    }
}

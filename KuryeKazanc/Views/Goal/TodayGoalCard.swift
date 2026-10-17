import SwiftUI

/// Bugun: gunluk hedefe ne kaldigi tek satir ve ilerleme cubugu; dokununca plan. Hedef yoksa yalnizca "Hedef koy".
/// 1.15 sade: halka, ipucu baloncugu ve ayri plan dugmesi kalkti; kartin tamami plana gider.
struct TodayGoalCard: View {
    let progress: DailyGoalProgress?
    let hasGoal: Bool

    var body: some View {
        NavigationLink {
            GoalPlanView()
        } label: {
            if hasGoal, let progress {
                VStack(alignment: .leading, spacing: 8) {
                    Text(line(progress))
                        .font(.headline)
                        .monospacedDigit()
                    ProgressView(value: min(1, max(0, progress.fraction)))
                        .tint(Theme.accent)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("today.goalCard")
            } else {
                Label("Hedef koy", systemImage: "target")
                    .font(.headline)
                    .padding(.vertical, 6)
            }
        }
        .accessibilityIdentifier("today.planButton")
    }

    private func line(_ progress: DailyGoalProgress) -> String {
        let left: Int = progress.targetPackages - progress.packages
        if progress.targetPackages == 0 || left <= 0 { return "Bugünün hedefi tamam" }
        return "Hedefe \(left) paket kaldı"
    }
}

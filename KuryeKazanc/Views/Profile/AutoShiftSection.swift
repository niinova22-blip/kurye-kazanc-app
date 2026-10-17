import SwiftUI

/// Profil > Otomatik vardiya: anahtar, calisma saatleri, izin uyarisi.
struct AutoShiftSection: View {
    @Environment(AutoShiftCoordinator.self) private var autoShift
    @Environment(ProStore.self) private var pro
    @Environment(\.openURL) private var openURL
    @State private var showIntro = false
    @State private var hours: WorkHours = .standard

    var body: some View {
        Section {
            // Liste icinde Section'a eklenen degistiriciler her satira uygulanabilir:
            // onAppear ve sheet her zaman var olan anahtar satirinda durur.
            Toggle("Otomatik vardiya", isOn: enabledBinding)
                .accessibilityIdentifier("profile.autoShift")
                .onAppear { hours = autoShift.workHours }
                .sheet(isPresented: $showIntro) {
                    AutoShiftIntroView {
                        let coordinator: AutoShiftCoordinator = autoShift
                        Task { _ = await coordinator.enable() }
                    }
                }

            if autoShift.isEnabled {
                hoursRows
            }

            // Kapaliyken de gosterilir: hareket izni reddedilince anahtar kapali kalir, uyari kalir
            if let problem = autoShift.permissionProblem {
                Button(action: openSystemSettings) {
                    Label(problemText(problem), systemImage: "exclamationmark.triangle")
                }
                .accessibilityIdentifier("profile.autoShiftPermission")
            }
        } header: {
            HStack(spacing: 6) {
                Text("Otomatik vardiya")
            }
        } footer: {
            Text("Yola çıkınca vardiya kendiliğinden başlar, 20 dakika durunca biter.")
        }
    }

    /// Acmak once aciklama ekranini gosterir (izinler onaydan sonra istenir); kapatmak hemen kapatir.
    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { autoShift.isEnabled },
            set: { newValue in
                if newValue {
                    // 1.14: otomatik vardiya Pro'da
                    guard pro.require(.autoShift) else { return }
                    showIntro = true
                } else {
                    autoShift.disable()
                }
            }
        )
    }

    @ViewBuilder
    private var hoursRows: some View {
        Toggle("Her saatte", isOn: alwaysBinding)
            .accessibilityIdentifier("profile.autoShiftAlways")
        if !hours.isAlways {
            DatePicker("Başlangıç", selection: minuteBinding(\.startMinute), displayedComponents: .hourAndMinute)
                .environment(\.locale, Formatters.locale)
            DatePicker("Bitiş", selection: minuteBinding(\.endMinute), displayedComponents: .hourAndMinute)
                .environment(\.locale, Formatters.locale)
        }
    }

    private var alwaysBinding: Binding<Bool> {
        Binding(
            get: { hours.isAlways },
            set: { newValue in
                hours.isAlways = newValue
                save()
            }
        )
    }

    private func problemText(_ problem: AutoShiftCoordinator.PermissionProblem) -> String {
        switch problem {
        case .motion: "Hareket ve Fitness izni kapalı — Ayarlar'dan aç"
        case .locationAlways: "Konum izni “Her zaman” olmalı — Ayarlar'dan aç"
        }
    }

    private func save() {
        autoShift.workHours = hours
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    /// Gun icindeki dakika <-> DatePicker tarihi.
    private func minuteBinding(_ keyPath: WritableKeyPath<WorkHours, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute: Int = hours[keyPath: keyPath]
                let day: Date = Calendar.current.startOfDay(for: .now)
                return day.addingTimeInterval(TimeInterval(minute * 60))
            },
            set: { date in
                let parts: DateComponents = Calendar.current.dateComponents([.hour, .minute], from: date)
                let minute: Int = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                hours[keyPath: keyPath] = minute
                save()
            }
        )
    }
}

/// Otomatik vardiyayi acmadan once kisa aciklama; onayda izinler sirayla istenir.
struct AutoShiftIntroView: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            List {
                introSection
                Section("İstenecek izinler") {
                    Label("Hareket ve Fitness — yola çıktığını anlamak için", systemImage: "figure.walk.motion")
                    Label("Konum “Her zaman” — uygulama kapalıyken de başlatabilmek için", systemImage: "location")
                    Label("Bildirimler — başladı/bitti haberi için", systemImage: "bell")
                }
                Section {
                    Text("Vardiya dışında konum yalnızca kabaca (~500 m) kontrol edilir; konumun cihazından çıkmaz.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button("Otomatik vardiyayı aç") {
                        onContinue()
                        dismiss()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("autoShift.enable")
                    Button("Şimdi değil") { dismiss() }
                        .font(.subheadline)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "scooter")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text("Vardiyan kendiliğinden başlasın mı?")
                    .font(.title2.bold())
                Text("Motorla ya da bisikletle yola çıktığında vardiyanı başlatır ve km'ni sayar; 20 dakika durunca bitirir. Yanlış başlarsa bildirimden tek dokunuşla iptal edersin.")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Şimdi değil") { dismiss() }
                .accessibilityIdentifier("autoShift.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Aç") {
                onContinue()
                dismiss()
            }
            .bold()
            .accessibilityIdentifier("autoShift.continue")
        }
    }
}

import SwiftUI

/// Calisma profili: platform hesaplari, uygun saatler, alinan slot/vardiyalar, giderler ve sinirlar.
/// Kullanici verisidir; dogrulanmis platform kurallarindan ayri saklanir.
struct WorkProfileView: View {
    let model: PlannerViewModel
    @State private var draft: WorkProfile = WorkProfile()
    @State private var loaded = false
    @State private var showAddReservation = false

    private static let weekdays: [(Int, String)] = [
        (1, "Pazartesi"), (2, "Salı"), (3, "Çarşamba"), (4, "Perşembe"), (5, "Cuma"), (6, "Cumartesi"), (7, "Pazar"),
    ]

    var body: some View {
        Form {
            platformsSection
            availabilitySection
            reservationsSection
            costsSection
            limitsSection
        }
        .navigationTitle("Çalışma profili")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            draft = model.profile
            loaded = true
        }
        .onChange(of: draft) { _, newValue in
            guard loaded else { return }
            model.saveProfile(newValue)
        }
        .sheet(isPresented: $showAddReservation) {
            ReservationForm(platforms: draft.platforms.filter(\.isActive).map(\.code), name: model.name, day: model.day) { block in
                draft.reserved.append(block)
            }
        }
    }

    // MARK: - Platformlar

    private var platformsSection: some View {
        Section {
            ForEach($draft.platforms) { $platform in
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(model.name(platform.code), isOn: $platform.isActive)
                    if platform.isActive {
                        Picker("Çalışma modeli", selection: $platform.courierModel) {
                            ForEach(CourierModel.allCases.filter { $0 != .any }) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        .font(.subheadline)
                        HStack {
                            Text("Sunulan saatlik ücret").font(.subheadline)
                            Spacer()
                            TextField("yok", value: $platform.offeredHourlyRate, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                            Text("₺/sa").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Platform hesapların")
        } footer: {
            Text("Yalnızca hesabın açık ve çalışma iznin olan platformları işaretle. Saatlik ücreti yalnızca platform sana yazılı olarak sunduysa gir; kaydın yoksa tahmin bununla yapılır.")
        }
    }

    // MARK: - Uygun saatler

    private var availabilitySection: some View {
        Section {
            TextField("Bölge (ör. Ankara/Sincan)", text: Binding(
                get: { draft.region ?? "" },
                set: { draft.region = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
            ))
            ForEach(Self.weekdays, id: \.0) { weekday, title in
                DayAvailabilityRow(title: title, ranges: Binding(
                    get: { draft.availability[weekday] ?? [] },
                    set: { draft.availability[weekday] = $0 }
                ))
            }
        } header: {
            Text("Bölge ve uygun saatler")
        } footer: {
            Text("Gece yarısını aşan saatler o günün sonunda (24:00) kesilir.")
        }
    }

    // MARK: - Slotlar

    private var reservationsSection: some View {
        Section {
            ForEach(draft.reserved.sorted { $0.start < $1.start }) { block in
                VStack(alignment: .leading) {
                    Text(model.name(block.platformCode)).font(.subheadline.weight(.semibold))
                    Text(block.start.formatted(date: .abbreviated, time: .shortened) + " – " + block.end.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button("Sil", role: .destructive) {
                        draft.reserved.removeAll { $0.id == block.id }
                    }
                }
            }
            Button("Slot / vardiya ekle") { showAddReservation = true }
                .disabled(draft.activePlatformCodes.isEmpty)
        } header: {
            Text("Aldığın slotlar ve vardiyalar")
        } footer: {
            Text("Slotla ya da vardiyayla çalışılan platformlarda plan yalnızca buraya girdiğin saatleri kullanır.")
        }
    }

    // MARK: - Giderler

    private var costsSection: some View {
        Section {
            numberRow("Km başı yakıt + bakım", value: $draft.costPerKm, unit: "₺")
            numberRow("Vergi oranı", value: Binding(
                get: { draft.taxRate * 100 },
                set: { draft.taxRate = min(max($0, 0), 100) / 100 }
            ), unit: "%")
            numberRow("Aylık Bağ-Kur / SGK", value: $draft.monthlySocialSecurity, unit: "₺")
            numberRow("Diğer aylık sabit (muhasebe vb.)", value: $draft.monthlyOtherFixed, unit: "₺")
        } header: {
            Text("Giderler")
        } footer: {
            Text("Aylık sabit giderler 26 iş gününe bölünür. Vergi oranını muhasebecine sor; bilmiyorsan 0 bırak.")
        }
    }

    private var limitsSection: some View {
        Section("Sınırlar ve hedef") {
            Stepper("Günlük en fazla \(Int(draft.maxHoursPerDay)) sa", value: $draft.maxHoursPerDay, in: 1...16, step: 1)
            Stepper("Platform geçişi \(draft.switchBufferMinutes) dk", value: $draft.switchBufferMinutes, in: 0...90, step: 5)
            numberRow("Günlük net hedef", value: Binding(
                get: { draft.dailyNetTarget ?? 0 },
                set: { draft.dailyNetTarget = $0 > 0 ? $0 : nil }
            ), unit: "₺")
        }
    }

    private func numberRow(_ title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}

/// Bir gunun tek uygunluk araligi (bos = calismiyor).
private struct DayAvailabilityRow: View {
    let title: String
    @Binding var ranges: [TimeRange]

    private var isOn: Binding<Bool> {
        Binding(
            get: { !ranges.isEmpty },
            set: { ranges = $0 ? [TimeRange(startMinute: 10 * 60, endMinute: 23 * 60)] : [] }
        )
    }

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(title, isOn: isOn)
            if let first = ranges.first {
                HStack {
                    DatePicker("Başlangıç", selection: minuteBinding(first.startMinute) { ranges[0].startMinute = $0 }, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("–")
                    DatePicker("Bitiş", selection: minuteBinding(first.endMinute) { ranges[0].endMinute = $0 }, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
        }
    }

    private func minuteBinding(_ minute: Int, set: @escaping (Int) -> Void) -> Binding<Date> {
        let base: Date = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 0))
        return Binding(
            get: { base.addingTimeInterval(TimeInterval(min(minute, 1439) * 60)) },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                let value: Int = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                // 00:00 bitis = gun sonu
                set(value == 0 && minute >= 1439 ? 1440 : value)
            }
        )
    }
}

private struct ReservationForm: View {
    let platforms: [String]
    let name: (String) -> String
    let day: Date
    let onSave: (ReservedBlock) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var platform: String = ""
    @State private var start: Date = .now
    @State private var end: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Picker("Platform", selection: $platform) {
                    ForEach(platforms, id: \.self) { Text(name($0)).tag($0) }
                }
                DatePicker("Başlangıç", selection: $start)
                DatePicker("Bitiş", selection: $end, in: start...)
            }
            .navigationTitle("Slot / vardiya")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") {
                        onSave(ReservedBlock(platformCode: platform, start: start, end: end))
                        dismiss()
                    }
                    .disabled(platform.isEmpty || end <= start)
                }
            }
            .onAppear {
                platform = platforms.first ?? ""
                let base: Date = Calendar.current.startOfDay(for: day)
                start = base.addingTimeInterval(18 * 3600)
                end = base.addingTimeInterval(22 * 3600)
            }
        }
    }
}

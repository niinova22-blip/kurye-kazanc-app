import SwiftUI
import SwiftData

struct ExpenseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ExpenseFormViewModel
    @State private var saveError: String?

    init(record: ExpenseRecord? = nil) {
        _viewModel = State(initialValue: ExpenseFormViewModel(record: record))
    }

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            Form {
                Section {
                    Picker("Tür", selection: $vm.type) {
                        ForEach(ExpenseType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .accessibilityIdentifier("expenseForm.type")

                    AmountField(title: "Tutar", text: $vm.amountText, identifier: "expenseForm.amount")

                    DatePicker("Tarih", selection: $vm.date, displayedComponents: .date)
                        .environment(\.locale, Formatters.locale)

                    TextField("Not (isteğe bağlı)", text: $vm.note)
                } footer: {
                    if vm.replacesEstimate {
                        Text("Bu gün için yakıt/bakım gideri girdiğinde km başına otomatik tahmin o gün kullanılmaz (çift sayılmaz).")
                    }
                }
            }
            .dismissesKeyboard()
            .navigationTitle(vm.isEditing ? "Gideri düzenle" : "Gider ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                        .accessibilityIdentifier("form.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        do {
                            try viewModel.save(in: modelContext)
                            dismiss()
                        } catch {
                            saveError = error.localizedDescription
                        }
                    }
                    .disabled(!vm.canSave)
                    .accessibilityIdentifier("form.save")
                }
            }
            .alert("Kaydedilemedi", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }
}

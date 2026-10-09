import SwiftUI
import UIKit

/// Formlarda klavyeyi kapatma: kaydirinca kapanir ve klavyenin ustunde "Bitti" dugmesi olur
/// (sayi klavyesinde donus tusu yoktur; bos alana dokunmak Form'da klavyeyi kapatmaz).
struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .accessibilityIdentifier("keyboard.done")
                }
            }
    }
}

extension View {
    func dismissesKeyboard() -> some View {
        modifier(KeyboardDismissModifier())
    }
}

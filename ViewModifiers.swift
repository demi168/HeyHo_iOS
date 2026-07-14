import SwiftUI

// エラーアラートを表示する共通ViewModifier
struct ErrorAlert: ViewModifier {
    @Binding var errorMessage: String?
    var title: String = "エラー"
    var actionTitle: String = "OK"

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: .constant(errorMessage != nil)) {
                Button(actionTitle) { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
    }
}

extension View {
    func errorAlert(_ errorMessage: Binding<String?>, title: String = "エラー", actionTitle: String = "OK") -> some View {
        modifier(ErrorAlert(errorMessage: errorMessage, title: title, actionTitle: actionTitle))
    }
}

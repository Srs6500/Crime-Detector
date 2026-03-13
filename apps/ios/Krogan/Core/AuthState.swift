import Foundation
import SwiftUI

@MainActor
final class AuthState: ObservableObject {
    @Published private(set) var isSignedIn: Bool
    /// Shown on auth screen when we signed out due to invalid/expired session (e.g. 401 from /me).
    @Published var sessionExpiredMessage: String?

    init() {
        self.isSignedIn = KeychainService.getToken() != nil
    }

    func didSignIn() {
        sessionExpiredMessage = nil
        isSignedIn = true
    }

    func signOut(reason: String? = nil) {
        KeychainService.deleteToken()
        sessionExpiredMessage = reason
        isSignedIn = false
    }
}

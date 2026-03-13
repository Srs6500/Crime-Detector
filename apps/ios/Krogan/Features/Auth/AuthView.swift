import AuthenticationServices
import SwiftUI
import UIKit

struct AuthView: View {
    @EnvironmentObject var authState: AuthState
    @State private var showPhoneEntry = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var appleCoordinator: SignInWithAppleCoordinator?

    var body: some View {
        VStack(spacing: 24) {
            Text("Krogan")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Your quiet companion.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            if let msg = authState.sessionExpiredMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .onAppear { authState.sessionExpiredMessage = nil }
            }
            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                startAppleSignIn()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                    Text("Sign in with Apple")
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 40)
            .disabled(isLoading)

            Text("Sign in with Apple can be unreliable on Simulator. If it fails, use \"Continue with phone number\" below.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Continue with phone number") {
                showPhoneEntry = true
            }
            .disabled(isLoading)

            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .sheet(isPresented: $showPhoneEntry) {
            PhoneEntryView { success in
                if success { authState.didSignIn() }
                showPhoneEntry = false
            }
        }
    }

    private func startAppleSignIn() {
        errorMessage = nil
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) else {
            errorMessage = "Could not show sign-in. Try again or use phone number."
            return
        }
        let coordinator = SignInWithAppleCoordinator()
        appleCoordinator = coordinator
        Task {
            let result = await coordinator.performRequest(presentationAnchor: window)
            await MainActor.run {
                handleAppleSignIn(result)
                appleCoordinator = nil
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Could not get Apple credential."
                return
            }
            Task {
                await signInWithApple(identityToken: identityToken)
            }
        case .failure(let error):
            let code = (error as NSError).code
            if code == ASAuthorizationError.canceled.rawValue { return }
            if code == 1000 {
                errorMessage = "Sign in with Apple isn’t available here (common on Simulator). Use \"Continue with phone number\" instead."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signInWithApple(identityToken: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let client = APIClient(token: nil)
            let body = AppleTokenRequest(identity_token: identityToken, authorization_code: nil)
            let response: AuthResponse = try await client.post("/api/v1/auth/apple", body: body)
            KeychainService.saveToken(response.accessToken)
            if KeychainService.getToken() != nil {
                await MainActor.run { authState.didSignIn() }
            } else {
                await MainActor.run { errorMessage = "Could not save session. Try again." }
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError).map { err in
                    switch err {
                    case .httpStatus(401, _): return "Apple sign-in couldn’t be verified. Try again or use phone number."
                    case .httpStatus(let code, _): return "Sign in failed (\(code)). Try again."
                    default: return "Sign in failed. Try again."
                    }
                } ?? "Sign in failed. Try again."
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthState())
}

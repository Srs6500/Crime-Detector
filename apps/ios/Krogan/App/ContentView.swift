import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authState: AuthState
    @State private var hasValidatedToken = false
    @State private var showingSessionSheet = false
    @State private var sessionDraft = SessionDraft()
    @State private var lastSessionSummary: String?
    @State private var activeSession: SessionResponse?
    @State private var showingActiveSession = false
    @State private var sessionError: String?
    @State private var isStartingSession = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Krogan")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Your quiet companion.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            if let err = sessionError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else if let summary = lastSessionSummary {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("When you’re heading into something that might feel off, start a session so we can quietly watch over you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 16)

            Button {
                sessionError = nil
                showingSessionSheet = true
            } label: {
                Text("Walk with me")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
            }
            .padding(.horizontal, 32)
            .disabled(isStartingSession)

            if isStartingSession {
                ProgressView()
                    .padding(.top, 8)
            }

            Spacer()

            Button("Sign out") {
                authState.signOut()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .task {
            guard !hasValidatedToken else { return }
            hasValidatedToken = true
            await validateToken()
        }
        .sheet(isPresented: $showingSessionSheet) {
            SessionSetupView(draft: $sessionDraft) { draft in
                showingSessionSheet = false
                startSession(draft)
            }
        }
        .fullScreenCover(isPresented: $showingActiveSession) {
            if let session = activeSession {
                ActiveSessionView(session: session) { noteCount in
                    showingActiveSession = false
                    let modeText = session.mode.capitalized
                    if noteCount > 0 {
                        lastSessionSummary = "Ended \(modeText.lowercased()) session safely (\(noteCount) note\(noteCount == 1 ? "" : "s"))."
                    } else {
                        lastSessionSummary = "Ended \(modeText.lowercased()) session safely."
                    }
                    activeSession = nil
                }
            }
        }
    }

    private func startSession(_ draft: SessionDraft) {
        isStartingSession = true
        sessionError = nil
        Task {
            await doStartSession(draft)
        }
    }

    private func doStartSession(_ draft: SessionDraft) async {
        defer { Task { @MainActor in isStartingSession = false } }
        do {
            let client = APIClient()
            let body = SessionCreateRequest(
                mode: draft.mode.rawValue,
                context: draft.context.isEmpty ? nil : draft.context,
                etaMinutes: draft.etaMinutes
            )
            let response: SessionResponse = try await client.post("/api/v1/sessions", body: body)
            await MainActor.run {
                activeSession = response
                showingActiveSession = true
            }
        } catch {
            await MainActor.run {
                sessionError = (error as? APIError).map { err in
                    switch err {
                    case .httpStatus(409, _): return "You already have an active session. End it first."
                    case .httpStatus(401, _):
                        authState.signOut(reason: "Session expired. Please sign in again.")
                        return "Session expired. Please sign in again."
                    case .httpStatus(let code, _): return "Could not start session (\(code)). Try again."
                    default: return "Could not start session. Try again."
                    }
                } ?? "Could not start session. Try again."
            }
        }
    }

    private func validateToken() async {
        do {
            let client = APIClient()
            _ = try await client.get("/api/v1/me") as UserResponse
            // After verifying the token, restore any active session.
            await loadActiveSession(with: client)
        } catch {
            if case .httpStatus(401, _) = error as? APIError {
                await MainActor.run {
                    authState.signOut(reason: "Session expired. Please sign in again.")
                }
            }
        }
    }

    private func loadActiveSession(with client: APIClient) async {
        do {
            let active: SessionResponse? = try await client.get("/api/v1/sessions/active")
            guard let session = active else { return }
            await MainActor.run {
                activeSession = session
                showingActiveSession = true
            }
        } catch {
            // If this fails we just skip restoring; auth errors are already handled elsewhere.
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthState())
}

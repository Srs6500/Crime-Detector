import SwiftUI

struct ActiveSessionView: View {
    let session: SessionResponse
    let onEnd: (_ noteCount: Int) -> Void

    @State private var isEnding = false
    @State private var isEscalating = false
    @State private var errorMessage: String?
    @State private var notes: [String] = []
    @State private var noteText: String = ""
    @State private var hasGuardians = true
    @State private var isDashcamOn = false
    @State private var showStealthWarning = false
    @State private var isInStealthMode = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                emergencyButton
                notesList
                noteInput
                endButton
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Walk with me")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadGuardianState()
            }
            .fullScreenCover(isPresented: $isInStealthMode) {
                StealthModeView(
                    onExit: { isInStealthMode = false },
                    onEscalate: { escalateSession(trigger: "stealth_manual") }
                )
            }
            .alert("Enter Stealth Mode?", isPresented: $showStealthWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Enter Stealth Mode") {
                    isInStealthMode = true
                }
            } message: {
                Text("Controlled high-risk mode. The screen will look harmless while monitoring stays active in the background.")
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                Text("Monitoring active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(session.mode.capitalized)
                    .font(.headline)
                if let ctx = session.context, !ctx.isEmpty {
                    Text(ctx)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let eta = session.etaMinutes {
                    Text("ETA ~\(eta) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    private var notesList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if notes.isEmpty {
                    Text("You can quietly add short notes here if something feels off. These stay with the session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(notes.enumerated()), id: \.offset) { idx, note in
                        HStack(alignment: .top, spacing: 8) {
                            Text("#\(idx + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(note)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var noteInput: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                TextField("Add a quick note about what’s happening", text: $noteText, axis: .vertical)
                    .lineLimit(1...3)
                Button {
                    addNote()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)

            HStack {
                Button {
                    if hasGuardians {
                        isDashcamOn.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isDashcamOn ? "video.fill.badge.checkmark" : "video.badge.ellipsis")
                        Text(isDashcamOn ? "Dashcam on" : "Dashcam")
                    }
                }
                .font(.caption)
                .foregroundStyle(isDashcamOn ? .red : .primary)
                .disabled(!hasGuardians)
                .padding(.horizontal, 24)
                Spacer()
            }
        }
    }

    private var emergencyButton: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    showStealthWarning = true
                } label: {
                    Label("Enter Stealth Mode", systemImage: "eye.slash")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    escalateSession()
                } label: {
                    Label(isEscalating ? "Requesting…" : "Request Overwatch", systemImage: "exclamationmark.shield")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal, 24)
            .disabled(isEscalating || isEnding)

            Text("Use Stealth Mode for discreet operation. Overwatch sends immediate manual escalation.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
    }

    private var endButton: some View {
        VStack {
            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button {
                endSession()
            } label: {
                Text("End safely")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .disabled(isEnding)
        }
    }

    private func addNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes.append(trimmed)
        noteText = ""
    }

    private func endSession() {
        errorMessage = nil
        isEnding = true
        Task {
            await doEndSession()
        }
    }

    private func escalateSession(trigger: String = "user_tap") {
        guard !isEscalating else { return }
        errorMessage = nil
        isEscalating = true
        Task {
            defer { Task { @MainActor in isEscalating = false } }
            do {
                let client = APIClient()
                _ = try await client.post(
                    "/api/v1/sessions/\(session.id)/escalate",
                    body: SessionEscalateRequest(trigger: trigger)
                ) as SessionEscalateResponse
                await MainActor.run {
                    errorMessage = "Help request sent. Stay on this screen."
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError).map { err in
                        switch err {
                        case .httpStatus(400, _): return "Session is not active."
                        case .httpStatus(404, _): return "Session not found."
                        case .httpStatus(let code, _): return "Could not send help request (\(code))."
                        default: return "Could not send help request."
                        }
                    } ?? "Could not send help request."
                }
            }
        }
    }

    private func loadGuardianState() async {
        do {
            let client = APIClient()
            let guardians: [GuardianResponse] = try await client.get("/api/v1/guardians")
            await MainActor.run {
                hasGuardians = !guardians.isEmpty
                // Product rule: if user has no guardians, dashcam stays on for the whole session.
                isDashcamOn = guardians.isEmpty ? true : isDashcamOn
            }
        } catch {
            // Fail-safe: assume guardians exist to avoid forcing dashcam without certainty.
            await MainActor.run {
                hasGuardians = true
            }
        }
    }

    private func doEndSession() async {
        defer { Task { @MainActor in isEnding = false } }
        do {
            let client = APIClient()
            _ = try await client.patch("/api/v1/sessions/\(session.id)/end") as SessionResponse
            let count = notes.count
            await MainActor.run { onEnd(count) }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError).map { err in
                    switch err {
                    case .httpStatus(404, _): return "Session not found."
                    case .httpStatus(let code, _): return "Could not end session (\(code)). Try again."
                    default: return "Could not end session. Try again."
                    }
                } ?? "Could not end session. Try again."
            }
        }
    }
}

private struct StealthModeView: View {
    let onExit: () -> Void
    let onEscalate: () -> Void

    @State private var showExitControls = false
    @State private var subtleStatus: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showExitControls {
                VStack(spacing: 20) {
                    Text("Stealth Mode Active")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))

                    if let subtleStatus {
                        Text(subtleStatus)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Button("Exit Stealth") { onExit() }
                        .buttonStyle(.borderedProminent)

                    Button("Request Overwatch") {
                        onEscalate()
                        subtleStatus = "Overwatch requested"
                    }
                    .buttonStyle(.bordered)
                }
                .padding(24)
            } else {
                VStack {
                    Spacer()
                    Text("Hold anywhere for controls")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.2))
                        .padding(.bottom, 24)
                }
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showExitControls = true
            }
        }
        .onTapGesture(count: 2) {
            // Discreet fallback while controls are hidden.
            onEscalate()
            subtleStatus = "Overwatch requested"
        }
    }
}

#Preview {
    ActiveSessionView(
        session: SessionResponse(
            id: "preview",
            mode: "walking",
            context: "Walking home",
            etaMinutes: 15,
            status: "active",
            startedAt: nil,
            endedAt: nil
        ),
        onEnd: { _ in }
    )
}

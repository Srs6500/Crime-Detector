import SwiftUI

struct ActiveSessionView: View {
    let session: SessionResponse
    let onEnd: (_ noteCount: Int) -> Void

    @State private var isEnding = false
    @State private var errorMessage: String?
    @State private var notes: [String] = []
    @State private var noteText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                notesList
                noteInput
                endButton
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Walk with me")
            .navigationBarTitleDisplayMode(.inline)
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
                    // Placeholder: this will open the dashcam view later.
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "video.badge.ellipsis")
                        Text("Dashcam")
                    }
                }
                .font(.caption)
                .padding(.horizontal, 24)
                Spacer()
            }
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

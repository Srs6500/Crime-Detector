import SwiftUI

struct SessionSetupView: View {
    @Binding var draft: SessionDraft
    let onStart: (SessionDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPresetMinutes: Int? = 15

    private let etaPresets: [Int] = [5, 10, 15, 30, 45, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    ForEach(SessionMode.allCases) { mode in
                        Button {
                            draft.mode = mode
                        } label: {
                            HStack {
                                Image(systemName: mode.systemImage)
                                    .foregroundStyle(Color.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.title)
                                    Text(mode.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if draft.mode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Context (optional)") {
                    TextField("e.g. Uber from X to Y, walking home, meeting from an app", text: $draft.context, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("ETA (optional)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(etaPresets, id: \.self) { minutes in
                                let isSelected = selectedPresetMinutes == minutes
                                Button("\(minutes)m") {
                                    selectedPresetMinutes = minutes
                                    draft.etaMinutes = minutes
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                                .clipShape(Capsule())
                            }

                            Button("No ETA") {
                                selectedPresetMinutes = nil
                                draft.etaMinutes = nil
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedPresetMinutes == nil ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                            .foregroundStyle(selectedPresetMinutes == nil ? Color.accentColor : .primary)
                            .clipShape(Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                    if let eta = draft.etaMinutes {
                        Text("We’ll treat this as your expected arrival in about \(eta) minutes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("You can always end the session manually.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Walk with me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        onStart(draft)
                        dismiss()
                    }
                    .disabled(isStartDisabled)
                }
            }
        }
    }

    private var isStartDisabled: Bool {
        // All fields are optional for now; allow immediate start.
        false
    }
}

#Preview {
    SessionSetupView(draft: .constant(SessionDraft())) { _ in }
}


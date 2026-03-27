import SwiftUI

struct ManageGuardiansView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var guardians: [GuardianResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddGuardian = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading guardians…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") { loadGuardians() }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(guardians, id: \.id) { g in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(g.name)
                                        .font(.headline)
                                    Text(g.phone)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(priorityLabel(g.priority))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteGuardian(id: g.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(isDeleting)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteGuardian(id: g.id)
                                } label: {
                                    Label("Remove guardian", systemImage: "trash")
                                }
                                .disabled(isDeleting)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Guardians")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddGuardian = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                loadGuardians()
            }
            .refreshable {
                await loadGuardiansAsync()
            }
            .sheet(isPresented: $showAddGuardian) {
                AddGuardianSheetView(onSave: {
                    showAddGuardian = false
                    loadGuardians()
                })
            }
        }
    }

    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 1: return "Primary"
        case 2: return "Secondary"
        default: return "Backup"
        }
    }

    private func loadGuardians() {
        Task { await loadGuardiansAsync() }
    }

    private func loadGuardiansAsync() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let client = APIClient()
            let list: [GuardianResponse] = try await client.get("/api/v1/guardians")
            await MainActor.run {
                guardians = list
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError).map { err in
                    switch err {
                    case .httpStatus(401, _): return "Session expired. Please sign in again."
                    case .httpStatus(let code, _): return "Could not load guardians (\(code))."
                    default: return "Could not load guardians."
                    }
                } ?? "Could not load guardians."
                isLoading = false
            }
        }
    }

    private func deleteGuardian(id: String) {
        guard !isDeleting else { return }
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                let client = APIClient()
                try await client.delete("/api/v1/guardians/\(id)")
                await MainActor.run {
                    guardians.removeAll { $0.id == id }
                    errorMessage = nil
                    isDeleting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError).map { err in
                        switch err {
                        case .httpStatus(401, _): return "Session expired. Please sign in again."
                        case .httpStatus(404, _): return "Guardian not found or already removed."
                        case .httpStatus(let code, _): return "Could not remove guardian (\(code))."
                        default: return "Could not remove guardian."
                        }
                    } ?? "Could not remove guardian."
                    isDeleting = false
                }
            }
        }
    }
}

// MARK: - Add guardian sheet (posts to API)
private struct AddGuardianSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: () -> Void
    @State private var name = ""
    @State private var phone = ""
    @State private var priority = 1
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                TextField("Name", text: $name)
                TextField("Phone (E.164, e.g. +15551234567)", text: $phone)
                    .keyboardType(.phonePad)
                Picker("Priority", selection: $priority) {
                    Text("Primary").tag(1)
                    Text("Secondary").tag(2)
                    Text("Backup").tag(3)
                }
            }
            .navigationTitle("Add guardian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveGuardian()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || phone.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func saveGuardian() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedPhone.isEmpty else { return }
        guard trimmedPhone.hasPrefix("+") else {
            errorMessage = "Phone must be E.164 (e.g. +15551234567)"
            return
        }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let client = APIClient()
                _ = try await client.post("/api/v1/guardians", body: GuardianCreateRequest(
                    name: trimmedName,
                    phone: trimmedPhone,
                    priority: priority
                )) as GuardianResponse
                await MainActor.run {
                    isSaving = false
                    onSave()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = (error as? APIError).map { err in
                        switch err {
                        case .httpStatus(400, _): return "Invalid phone. Use E.164 (e.g. +15551234567)."
                        case .httpStatus(401, _): return "Session expired. Sign in again."
                        case .httpStatus(let code, _): return "Could not add guardian (\(code))."
                        default: return "Could not add guardian."
                        }
                    } ?? "Could not add guardian."
                }
            }
        }
    }
}

#Preview {
    ManageGuardiansView()
}

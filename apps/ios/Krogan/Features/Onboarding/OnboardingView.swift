import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case consent
    case biometrics
    case guardians
    case locations
    case ready
}

struct OnboardingView: View {
    @ObservedObject var onboardingState: OnboardingState
    @State private var currentStep: OnboardingStep = .welcome
    @State private var consentAccepted = false
    @State private var consentRecording = false
    @State private var guardians: [GuardianPlaceholder] = []
    @State private var locations: [LocationPlaceholder] = []
    @State private var showAddGuardian = false
    @State private var showAddLocation = false

    var body: some View {
        VStack(spacing: 0) {
            stepContent
            Spacer(minLength: 24)
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .sheet(isPresented: $showAddGuardian) {
            AddGuardianSheet(guardians: $guardians)
        }
        .sheet(isPresented: $showAddLocation) {
            AddLocationSheet(locations: $locations)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            WelcomeStep(onNext: advance)
        case .consent:
            ConsentStep(
                consentAccepted: $consentAccepted,
                consentRecording: $consentRecording,
                onNext: advance
            )
        case .biometrics:
            BiometricsStep(onNext: advance)
        case .guardians:
            GuardiansStep(
                guardians: guardians,
                onAdd: { showAddGuardian = true },
                onNext: advance
            )
        case .locations:
            LocationsStep(
                locations: locations,
                onAdd: { showAddLocation = true },
                onNext: advance
            )
        case .ready:
            ReadyStep(onFinish: { Task { await finishOnboarding() } })
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case .consent: return consentAccepted && consentRecording
        default: return true
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            if currentStep != .welcome && currentStep != .ready {
                Button("Back") { goBack() }
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if currentStep != .ready {
                Button("Next") { advance() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAdvance)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentStep = next
        }
    }

    private func goBack() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentStep = prev
        }
    }

    private func finishOnboarding() async {
        await syncGuardiansAndLocationsToBackend()
        await MainActor.run {
            onboardingState.completeOnboarding()
        }
    }

    /// POST onboarding guardians and locations to the API. Best-effort; failures don't block completing onboarding.
    private func syncGuardiansAndLocationsToBackend() async {
        let client = APIClient()
        for g in guardians where g.phone.hasPrefix("+") {
            _ = try? await client.post("/api/v1/guardians", body: GuardianCreateRequest(
                name: g.name,
                phone: g.phone,
                priority: g.priority
            )) as GuardianResponse
        }
        for loc in locations {
            _ = try? await client.post("/api/v1/locations", body: LocationCreateRequest(
                kind: loc.kind,
                name: loc.name,
                latitude: nil,
                longitude: nil
            )) as SavedLocationResponse
        }
    }
}

// MARK: - Step views

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)
            Text("Welcome to Krogan")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("Your quiet companion. We’ll walk you through a few steps to get set up.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

private struct ConsentStep: View {
    @Binding var consentAccepted: Bool
    @Binding var consentRecording: Bool
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Consent & terms")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("To use Krogan, you need to accept the following. You are responsible for complying with local recording laws (one-party vs all-party consent) where you use the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Toggle("I accept the Terms of Service and Privacy Policy", isOn: $consentAccepted)
                Toggle("I consent to audio monitoring during sessions and understand my responsibility for recording laws", isOn: $consentRecording)
            }
            .padding(24)
        }
    }
}

private struct BiometricsStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)
            Image(systemName: "faceid")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Quick access")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Use Face ID or Touch ID to unlock Krogan quickly. You can enable this later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Enable Face ID / Touch ID") {
                // Placeholder: real implementation will use LocalAuthentication
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Button("Skip for now") { onNext() }
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

private struct GuardiansStep: View {
    let guardians: [GuardianPlaceholder]
    let onAdd: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Guardians")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Optional. Add people who can be notified when you start a session or if we detect a heads up. You can add or change them anytime in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(guardians) { g in
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
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button(action: onAdd) {
                Label("Add guardian", systemImage: "person.badge.plus")
            }
            .buttonStyle(.bordered)

            Button("I'll add guardians later") {
                onNext()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 8)

            Spacer()
        }
        .padding(24)
    }

    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 1: return "Primary"
        case 2: return "Secondary"
        default: return "Backup"
        }
    }
}

private struct LocationsStep: View {
    let locations: [LocationPlaceholder]
    let onAdd: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optional locations")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add home, campus, or work so we can use them as context. Optional.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(locations) { loc in
                HStack {
                    Image(systemName: iconName(loc.kind))
                        .foregroundStyle(.secondary)
                    Text(loc.name)
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button(action: onAdd) {
                Label("Add location", systemImage: "mappin.circle")
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(24)
    }

    private func iconName(_ kind: String) -> String {
        switch kind {
        case "home": return "house.fill"
        case "campus": return "building.2.fill"
        case "work": return "briefcase.fill"
        default: return "mappin"
        }
    }
}

private struct ReadyStep: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)
            Text("You’re all set")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Tap below to go to your home screen. When you’re ready, start a session with “Walk with me”.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Go to Home") { onFinish() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 24)
            Spacer()
        }
    }
}

// MARK: - Placeholder models (local only; will sync to backend later)

struct GuardianPlaceholder: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var phone: String
    var priority: Int // 1 primary, 2 secondary, 3 backup
}

struct LocationPlaceholder: Identifiable, Codable {
    var id: UUID = UUID()
    var kind: String // "home", "campus", "work"
    var name: String
}

// MARK: - Add sheets

private struct AddGuardianSheet: View {
    @Binding var guardians: [GuardianPlaceholder]
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var priority = 1

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Phone", text: $phone)
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guardians.append(GuardianPlaceholder(name: name, phone: phone, priority: priority))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || phone.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private struct AddLocationSheet: View {
    @Binding var locations: [LocationPlaceholder]
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "home"
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Home").tag("home")
                    Text("Campus").tag("campus")
                    Text("Work").tag("work")
                }
                TextField("Name (e.g. My apartment)", text: $name)
            }
            .navigationTitle("Add location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        locations.append(LocationPlaceholder(kind: kind, name: name.isEmpty ? kind.capitalized : name))
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView(onboardingState: OnboardingState())
}

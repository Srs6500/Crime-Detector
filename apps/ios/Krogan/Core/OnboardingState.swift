import Foundation
import SwiftUI

/// Tracks whether the user has completed onboarding. Persisted in UserDefaults.
/// App root shows OnboardingView when signed in and this is false.
@MainActor
final class OnboardingState: ObservableObject {
    private let key = "krogan.hasCompletedOnboarding"

    @Published private(set) var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: key) }
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: key)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

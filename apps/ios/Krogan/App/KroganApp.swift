import SwiftUI

@main
struct KroganApp: App {
    @StateObject private var authState = AuthState()
    @StateObject private var onboardingState = OnboardingState()

    var body: some Scene {
        WindowGroup {
            if authState.isSignedIn {
                if onboardingState.hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(authState)
                } else {
                    OnboardingView(onboardingState: onboardingState)
                }
            } else {
                AuthView()
                    .environmentObject(authState)
            }
        }
    }
}

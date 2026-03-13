import Foundation

enum Config {
    /// Backend base URL. Use localhost for simulator; for physical device use your Mac's IP.
    static var apiBaseURL: String {
        #if DEBUG
        return "http://localhost:8000"
        #else
        return ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "https://api.krogan.com"
        #endif
    }
}

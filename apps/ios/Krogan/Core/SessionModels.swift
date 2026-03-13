import Foundation
import SwiftUI

enum SessionMode: String, CaseIterable, Identifiable {
    case rideshare
    case walking
    case meetup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rideshare: return "Rideshare"
        case .walking: return "Walking"
        case .meetup: return "Meetup"
        }
    }

    var subtitle: String {
        switch self {
        case .rideshare: return "Uber, Lyft, taxi or similar"
        case .walking: return "Walking alone or with someone"
        case .meetup: return "Meeting someone (date, marketplace, etc.)"
        }
    }

    var systemImage: String {
        switch self {
        case .rideshare: return "car.fill"
        case .walking: return "figure.walk"
        case .meetup: return "person.2.fill"
        }
    }
}

struct SessionDraft {
    var mode: SessionMode = .walking
    var context: String = ""
    /// Minutes from now for ETA. Nil means no ETA.
    var etaMinutes: Int? = 15
}


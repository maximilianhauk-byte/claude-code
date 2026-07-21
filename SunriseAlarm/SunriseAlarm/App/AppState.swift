import Foundation

/// Tiny shared flag the notification delegate uses to tell the SwiftUI view layer
/// "the user tapped the wake notification, show the ringing screen now".
final class AppState: ObservableObject {
    static let shared = AppState()
    private init() {}

    @Published var pendingRingRequest = false
}

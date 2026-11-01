import Observation

@MainActor
@Observable
final class AppState {
    private(set) var pointsOfInterest: [PointOfInterest] = []
}

protocol PointOfInterestProviding: Sendable {
    func fetchPointsOfInterest() async throws -> [PointOfInterest]
}

struct PointOfInterest: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double
}

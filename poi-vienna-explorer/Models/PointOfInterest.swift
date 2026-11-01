struct PointOfInterest: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
}

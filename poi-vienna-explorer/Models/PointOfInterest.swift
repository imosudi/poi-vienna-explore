import Foundation

struct PointOfInterest: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let address: String?
    let informationURL: URL?
    let thumbnailURL: URL?
    let latitude: Double
    let longitude: Double
}

struct POIAnnotationDetails: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let address: String?
    let informationURL: URL?
    let thumbnailURL: URL?
    let latitude: Double
    let longitude: Double

    init(pointOfInterest: PointOfInterest) {
        id = pointOfInterest.id
        name = pointOfInterest.name
        address = pointOfInterest.address
        informationURL = pointOfInterest.informationURL
        thumbnailURL = pointOfInterest.thumbnailURL
        latitude = pointOfInterest.latitude
        longitude = pointOfInterest.longitude
    }
}

struct ViennaPOIFeatureCollection: Decodable {
    let type: String
    let features: [ViennaPOIFeature]
}

struct ViennaPOIFeature: Decodable {
    let id: String?
    let geometry: ViennaPOIGeometry?
    let properties: ViennaPOIProperties?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(String.self, forKey: .id)
        geometry = try? container.decode(ViennaPOIGeometry.self, forKey: .geometry)
        properties = try? container.decode(ViennaPOIProperties.self, forKey: .properties)
    }

    var pointOfInterest: PointOfInterest? {
        guard let geometry,
              geometry.type == "Point",
              let coordinates = geometry.coordinates,
              coordinates.count >= 2,
              let properties,
              let sourceName = properties.name,
              let name = Self.nonempty(sourceName)
        else {
            return nil
        }

        let longitude = coordinates[0]
        let latitude = coordinates[1]
        guard longitude.isFinite,
              latitude.isFinite,
              (-180...180).contains(longitude),
              (-90...90).contains(latitude)
        else {
            return nil
        }

        let stableID = Self.nonempty(id ?? "") ?? properties.objectID.map(String.init)
        guard let stableID else { return nil }

        return PointOfInterest(
            id: stableID,
            name: name,
            address: properties.address.flatMap(Self.nonempty),
            informationURL: Self.webURL(properties.informationURL),
            thumbnailURL: Self.webURL(properties.thumbnailURL),
            latitude: latitude,
            longitude: longitude
        )
    }

    nonisolated private static func nonempty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private static func webURL(_ value: String?) -> URL? {
        guard let value,
              let components = URLComponents(string: value),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host != nil
        else {
            return nil
        }
        return components.url
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case geometry
        case properties
    }
}

struct ViennaPOIGeometry: Decodable {
    let type: String
    let coordinates: [Double]?

    enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        coordinates = try? container.decode([Double].self, forKey: .coordinates)
    }
}

struct ViennaPOIProperties: Decodable {
    let objectID: Int?
    let name: String?
    let address: String?
    let informationURL: String?
    let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case objectID = "OBJECTID"
        case name = "NAME"
        case address = "ADRESSE"
        case informationURL = "WEITERE_INF"
        case thumbnailURL = "THUMBNAIL"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        objectID = try? container.decode(Int.self, forKey: .objectID)
        name = try? container.decode(String.self, forKey: .name)
        address = try? container.decode(String.self, forKey: .address)
        informationURL = try? container.decode(String.self, forKey: .informationURL)
        thumbnailURL = try? container.decode(String.self, forKey: .thumbnailURL)
    }
}

import Foundation

struct ViennaPOIService: PointOfInterestProviding {
    typealias DataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let endpoint = URL(
        string: "https://data.wien.gv.at/daten/geo?service=WFS&request=GetFeature&version=1.1.0&typeName=ogdwien:SEHENSWUERDIGOGD&srsName=EPSG:4326&outputFormat=json"
    )!

    private let dataLoader: DataLoader

    init(dataLoader: @escaping DataLoader = { request in
        try await URLSession.shared.data(for: request)
    }) {
        self.dataLoader = dataLoader
    }

    func fetchPointsOfInterest() async throws -> [PointOfInterest] {
        var request = URLRequest(url: Self.endpoint)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await dataLoader(request)
        guard let response = response as? HTTPURLResponse else {
            throw ViennaPOIServiceError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw ViennaPOIServiceError.httpStatusCode(response.statusCode)
        }

        let collection: FeatureCollection
        do {
            collection = try JSONDecoder().decode(FeatureCollection.self, from: data)
        } catch {
            throw ViennaPOIServiceError.malformedResponse
        }

        guard collection.type == "FeatureCollection" else {
            throw ViennaPOIServiceError.malformedResponse
        }

        return try collection.features.map { try $0.makePointOfInterest() }
    }
}

enum ViennaPOIServiceError: LocalizedError, Equatable {
    case invalidResponse
    case httpStatusCode(Int)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The Vienna data service returned an invalid response."
        case .httpStatusCode(let statusCode):
            return "The Vienna data service returned HTTP \(statusCode)."
        case .malformedResponse:
            return "The Vienna places data could not be read."
        }
    }
}

private struct FeatureCollection: Decodable {
    let type: String
    let features: [Feature]
}

private struct Feature: Decodable {
    let id: String
    let geometry: Geometry
    let properties: Properties

    func makePointOfInterest() throws -> PointOfInterest {
        guard geometry.coordinates.count >= 2 else {
            throw ViennaPOIServiceError.malformedResponse
        }

        let longitude = geometry.coordinates[0]
        let latitude = geometry.coordinates[1]
        guard longitude.isFinite,
              latitude.isFinite,
              (-180...180).contains(longitude),
              (-90...90).contains(latitude),
              !properties.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw ViennaPOIServiceError.malformedResponse
        }

        return PointOfInterest(
            id: id,
            name: properties.name,
            address: properties.address,
            latitude: latitude,
            longitude: longitude
        )
    }
}

private struct Geometry: Decodable {
    let coordinates: [Double]
}

private struct Properties: Decodable {
    let name: String
    let address: String?

    enum CodingKeys: String, CodingKey {
        case name = "NAME"
        case address = "ADRESSE"
    }
}

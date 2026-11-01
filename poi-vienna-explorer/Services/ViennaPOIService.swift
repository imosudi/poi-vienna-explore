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

        let collection: ViennaPOIFeatureCollection
        do {
            collection = try JSONDecoder().decode(ViennaPOIFeatureCollection.self, from: data)
        } catch {
            throw ViennaPOIServiceError.malformedResponse
        }

        guard collection.type == "FeatureCollection" else {
            throw ViennaPOIServiceError.malformedResponse
        }

        var seenIdentifiers = Set<String>()
        let places = collection.features
            .compactMap(\.pointOfInterest)
            .filter { seenIdentifiers.insert($0.id).inserted }
        guard collection.features.isEmpty || !places.isEmpty else {
            throw ViennaPOIServiceError.malformedResponse
        }
        return places
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

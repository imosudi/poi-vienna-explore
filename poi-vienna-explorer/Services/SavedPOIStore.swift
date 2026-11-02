import Foundation

struct SavedPOIStore {
    private static let schemaVersion = 1
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/SavedPOIs.json")
    }

    func load() throws -> [PointOfInterest] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let storedData: StoredPOIs
        do {
            storedData = try JSONDecoder().decode(StoredPOIs.self, from: data)
        } catch {
            throw SavedPOIStoreError.invalidFile(error.localizedDescription)
        }

        guard storedData.schemaVersion == Self.schemaVersion else {
            throw SavedPOIStoreError.unsupportedSchema(storedData.schemaVersion)
        }
        return storedData.places
    }

    @discardableResult
    func save(_ place: PointOfInterest) throws -> [PointOfInterest] {
        var places = try load()
        guard !places.contains(where: { $0.id == place.id }) else {
            return places
        }
        places.append(place)
        try write(places)
        return places
    }

    @discardableResult
    func remove(id: String) throws -> [PointOfInterest] {
        let places = try load()
        let remainingPlaces = places.filter { $0.id != id }
        guard remainingPlaces.count != places.count else {
            return places
        }
        try write(remainingPlaces)
        return remainingPlaces
    }

    private func write(_ places: [PointOfInterest]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder().encode(
            StoredPOIs(schemaVersion: Self.schemaVersion, places: places)
        )
        try data.write(to: fileURL, options: .atomic)
    }
}

private struct StoredPOIs: Codable {
    let schemaVersion: Int
    let places: [PointOfInterest]
}

enum SavedPOIStoreError: LocalizedError, Equatable {
    case invalidFile(String)
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .invalidFile(let reason):
            "Saved places could not be read: \(reason)"
        case .unsupportedSchema(let version):
            "Saved places use unsupported data version \(version)."
        }
    }
}

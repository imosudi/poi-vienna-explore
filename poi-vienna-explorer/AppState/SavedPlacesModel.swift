import Foundation
import Observation

@MainActor
@Observable
final class SavedPlacesModel {
    private(set) var places: [PointOfInterest] = []
    private(set) var errorMessage: String?
    private let store: SavedPOIStore

    init(store: SavedPOIStore? = nil) {
        let store = store ?? SavedPOIStore()
        self.store = store
        reload()
    }

    func reload() {
        do {
            places = try store.load()
            errorMessage = nil
        } catch {
            errorMessage = "Could not load favourites: \(error.localizedDescription)"
        }
    }

    func contains(_ place: PointOfInterest) -> Bool {
        places.contains(where: { $0.id == place.id })
    }

    func save(_ place: PointOfInterest) {
        do {
            places = try store.save(place)
            errorMessage = nil
        } catch {
            errorMessage = "Could not save favourite \(place.name): \(error.localizedDescription)"
        }
    }

    func remove(_ place: PointOfInterest) {
        do {
            places = try store.remove(id: place.id)
            errorMessage = nil
        } catch {
            errorMessage = "Could not remove favourite \(place.name): \(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }
}

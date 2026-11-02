import Foundation
import Observation

@MainActor
@Observable
final class CatalogueModel {
    enum QuickFilter: String, CaseIterable, Identifiable {
        case allPlaces = "All places"
        case withAddress = "With address"
        case withWebsite = "With website"

        var id: String { rawValue }
    }

    enum State {
        case idle
        case loading
        case loaded([PointOfInterest])
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var isRefreshing = false
    private(set) var refreshError: String?
    var searchText = ""
    var quickFilter: QuickFilter = .allPlaces
    private let provider: any PointOfInterestProviding

    var loadedPlaces: [PointOfInterest] {
        guard case .loaded(let places) = state else { return [] }
        return places
    }

    var hasLoadedPlaces: Bool {
        if case .loaded = state { return true }
        return false
    }

    var filteredPlaces: [PointOfInterest] {
        guard case .loaded(let places) = state else { return [] }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return places.filter { place in
            let matchesFilter: Bool
            switch quickFilter {
            case .allPlaces:
                matchesFilter = true
            case .withAddress:
                matchesFilter = place.address != nil
            case .withWebsite:
                matchesFilter = place.informationURL != nil
            }
            guard matchesFilter else { return false }
            guard !query.isEmpty else { return true }
            return [place.name, place.address, place.informationURL?.absoluteString]
                .compactMap { $0 }
                .contains { $0.localizedStandardContains(query) }
        }
    }

    init(provider: any PointOfInterestProviding) {
        self.provider = provider
    }

    init() {
        self.provider = ViennaPOIService()
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        state = .loading

        do {
            let places = try await provider.fetchPointsOfInterest()
            state = Task.isCancelled ? .idle : .loaded(places)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = Task.isCancelled ? .idle : .failed(error.localizedDescription)
        }
    }

    func retry() async {
        guard case .failed = state else { return }
        state = .idle
        await loadIfNeeded()
    }

    func refresh() async {
        guard case .loaded = state, !isRefreshing else { return }

        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }

        do {
            let places = try await provider.fetchPointsOfInterest()
            guard !Task.isCancelled else { return }
            state = .loaded(places)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            refreshError = "Could not refresh places: \(error.localizedDescription)"
        }
    }
}

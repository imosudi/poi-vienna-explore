import Foundation
import CoreLocation
import XCTest
@testable import poi_vienna_explorer

@MainActor
final class poi_vienna_explorerTests: XCTestCase {
    func testFetchMapsGeoJSONIntoPlaceModels() async throws {
        let service = makeService(statusCode: 200, body: try sourceFixture())

        let places = try await service.fetchPointsOfInterest()

        XCTAssertEqual(places.count, 2)
        XCTAssertEqual(places[0].id, "SEHENSWUERDIGOGD.640963")
        XCTAssertEqual(places[0].name, "Ankeruhr")
        XCTAssertEqual(places[0].address, "Hoher Markt 10/")
        XCTAssertEqual(places[0].latitude, 48.21076056)
        XCTAssertEqual(places[0].longitude, 16.37367575)
        XCTAssertEqual(places[0].informationURL?.absoluteString, "http://www.wien.info/article.asp?IDArticle=2018")
        XCTAssertEqual(places[0].thumbnailURL?.absoluteString, "https://www.wien.gv.at/viennagis/bubble/ankeruhr.jpg")
        XCTAssertEqual(places[1].name, "Friedhof St. Marx")
        XCTAssertEqual(places[1].latitude, 48.18297383)
        XCTAssertEqual(places[1].longitude, 16.40167012)
    }

    func testAnnotationDetailsRetainTheSelectedPlaceAttributes() throws {
        let first = PointOfInterest(
            id: "1",
            name: "First place",
            address: "First address",
            informationURL: try XCTUnwrap(URL(string: "https://example.com/first")),
            thumbnailURL: try XCTUnwrap(URL(string: "https://example.com/first.jpg")),
            latitude: 48.2,
            longitude: 16.3
        )
        let second = makePlace(id: "2", name: "Second place", address: "Second address")

        let firstDetails = POIAnnotationDetails(pointOfInterest: first)
        let secondDetails = POIAnnotationDetails(pointOfInterest: second)

        XCTAssertEqual(firstDetails.id, first.id)
        XCTAssertEqual(firstDetails.name, first.name)
        XCTAssertEqual(firstDetails.address, first.address)
        XCTAssertEqual(firstDetails.informationURL, first.informationURL)
        XCTAssertEqual(firstDetails.thumbnailURL, first.thumbnailURL)
        XCTAssertEqual(firstDetails.latitude, first.latitude)
        XCTAssertEqual(firstDetails.longitude, first.longitude)
        XCTAssertNotEqual(firstDetails, secondDetails)
        XCTAssertEqual(secondDetails.id, second.id)
        XCTAssertEqual(secondDetails.name, second.name)
        XCTAssertEqual(secondDetails.address, second.address)
    }

    func testAnnotationDetailsKeepMissingOptionalFieldsAbsent() {
        let details = POIAnnotationDetails(
            pointOfInterest: makePlace(id: "1", name: "Place without optional details")
        )

        XCTAssertNil(details.address)
        XCTAssertNil(details.informationURL)
        XCTAssertNil(details.thumbnailURL)
    }

    func testMarkerStyleUsesInformationLinkAndNeutralForMissingLink() throws {
        let linkedPlace = PointOfInterest(
            id: "1",
            name: "Place with link",
            address: nil,
            informationURL: try XCTUnwrap(URL(string: "https://example.com/place")),
            thumbnailURL: nil,
            latitude: 48.2,
            longitude: 16.3
        )
        let placeWithoutLink = makePlace(id: "2", name: "Place without link")

        XCTAssertEqual(POIMarkerStyle(pointOfInterest: linkedPlace), .informationLink)
        XCTAssertEqual(POIMarkerStyle(pointOfInterest: placeWithoutLink), .neutral)
        XCTAssertEqual(
            POIMarkerStyle(pointOfInterest: placeWithoutLink).accessibilityDescription,
            "No information link listed"
        )
    }

    func testDistanceUsesGreatCircleDistanceForKnownCoordinates() throws {
        let poi = PointOfInterest(
            id: "equator-east",
            name: "One degree east",
            address: nil,
            informationURL: nil,
            thumbnailURL: nil,
            latitude: 0,
            longitude: 1
        )
        let userCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)

        let distance = try XCTUnwrap(
            POIDistanceCalculator.distanceMeters(
                from: userCoordinate,
                to: poi
            )
        )

        XCTAssertEqual(distance, 111_195, accuracy: 100)
    }

    func testDistanceRejectsInvalidUserAndPOICoordinates() {
        let validUserCoordinate = CLLocationCoordinate2D(latitude: 48.2, longitude: 16.3)
        let invalidUserCoordinate = CLLocationCoordinate2D(latitude: 91, longitude: 16.3)
        let invalidPOI = PointOfInterest(
            id: "invalid",
            name: "Invalid coordinate",
            address: nil,
            informationURL: nil,
            thumbnailURL: nil,
            latitude: 48.2,
            longitude: .infinity
        )

        XCTAssertNil(
            POIDistanceCalculator.distanceMeters(
                from: invalidUserCoordinate,
                to: makePlace(id: "valid", name: "Valid coordinate")
            )
        )
        XCTAssertNil(
            POIDistanceCalculator.distanceMeters(
                from: validUserCoordinate,
                to: invalidPOI
            )
        )
    }

    func testDistanceFormattingUsesMetresAndKilometres() {
        XCTAssertEqual(POIDistanceFormatter.formattedDistance(meters: 245), "245 m")
        XCTAssertEqual(POIDistanceFormatter.formattedDistance(meters: 1_450), "1.5 km")
        XCTAssertEqual(POIDistanceFormatter.formattedDistance(meters: -.infinity), nil)
        XCTAssertEqual(POIDistanceFormatter.formattedDistance(meters: -1), nil)
    }

    func testSavedPOIIsAvailableFromANewStoreInstance() throws {
        let (directory, fileURL) = temporarySavedPlacesFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SavedPOIStore(fileURL: fileURL)
        let place = PointOfInterest(
            id: "SEHENSWUERDIGOGD.640963",
            name: "Ankeruhr",
            address: "Hoher Markt 10/",
            informationURL: URL(string: "https://example.com/ankeruhr"),
            thumbnailURL: URL(string: "https://example.com/ankeruhr.jpg"),
            latitude: 48.21076056,
            longitude: 16.37367575
        )

        try store.save(place)
        let relaunchedStore = SavedPOIStore(fileURL: fileURL)

        XCTAssertEqual(try relaunchedStore.load(), [place])
    }

    func testSavingSamePOIIdentifierDoesNotCreateDuplicate() throws {
        let (directory, fileURL) = temporarySavedPlacesFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SavedPOIStore(fileURL: fileURL)
        let original = makePlace(id: "stable-id", name: "Original")
        let updated = makePlace(id: "stable-id", name: "Updated")

        try store.save(original)
        let savedPlaces = try store.save(updated)

        XCTAssertEqual(savedPlaces.count, 1)
        XCTAssertEqual(savedPlaces.first?.name, "Original")
    }

    func testRemovingSavedPOIDeletesItFromPersistentStore() throws {
        let (directory, fileURL) = temporarySavedPlacesFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SavedPOIStore(fileURL: fileURL)
        let removedPlace = makePlace(id: "remove", name: "Remove")
        let retainedPlace = makePlace(id: "retain", name: "Retain")
        try store.save(removedPlace)
        try store.save(retainedPlace)

        let remainingPlaces = try store.remove(id: removedPlace.id)

        XCTAssertEqual(remainingPlaces, [retainedPlace])
        XCTAssertEqual(try SavedPOIStore(fileURL: fileURL).load(), [retainedPlace])
    }

    func testSavedPOIStoreRejectsUnsupportedSchemaVersion() throws {
        let (directory, fileURL) = temporarySavedPlacesFile()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try Data(#"{"schemaVersion":99,"places":[]}"#.utf8).write(to: fileURL)

        XCTAssertThrowsError(try SavedPOIStore(fileURL: fileURL).load()) { error in
            XCTAssertEqual(error as? SavedPOIStoreError, .unsupportedSchema(99))
        }
    }

    func testDuplicateIdentifiersProduceOnlyOnePlace() async throws {
        let duplicatedFeature = try XCTUnwrap(
            String(data: sourceFixture(), encoding: .utf8)
        ).replacingOccurrences(
            of: "\"id\": \"SEHENSWUERDIGOGD.640964\"",
            with: "\"id\": \"SEHENSWUERDIGOGD.640963\""
        )
        let service = makeService(
            statusCode: 200,
            body: Data(duplicatedFeature.utf8)
        )

        let places = try await service.fetchPointsOfInterest()

        XCTAssertEqual(places.map(\.id), ["SEHENSWUERDIGOGD.640963"])
        XCTAssertEqual(places.first?.name, "Ankeruhr")
    }

    func testSearchFiltersByNameAndAddressWithoutFetchingAgain() async throws {
        let provider = CountingPOIProvider(places: [
            PointOfInterest(
                id: "1",
                name: "Ankeruhr",
                address: "Hoher Markt 10/",
                informationURL: nil,
                thumbnailURL: nil,
                latitude: 48.21076056,
                longitude: 16.37367575
            ),
            PointOfInterest(
                id: "2",
                name: "Friedhof St. Marx",
                address: "Leberstraße 6-8",
                informationURL: nil,
                thumbnailURL: nil,
                latitude: 48.18297383,
                longitude: 16.40167012
            )
        ])
        let model = CatalogueModel(provider: provider)

        await model.loadIfNeeded()
        model.searchText = "leberstraße"

        XCTAssertEqual(model.filteredPlaces.map(\.id), ["2"])

        let requestCount = provider.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testRefreshReplacesPlacesAfterSuccessfulFetch() async throws {
        let original = makePlace(id: "1", name: "Original")
        let updated = makePlace(id: "2", name: "Updated")
        let provider = RefreshPOIProvider(outcomes: [
            .success([original]),
            .success([updated])
        ])
        let model = CatalogueModel(provider: provider)

        await model.loadIfNeeded()
        await model.refresh()

        XCTAssertEqual(loadedPlaceIDs(in: model), ["2"])
        XCTAssertNil(model.refreshError)
        XCTAssertFalse(model.isRefreshing)
        XCTAssertEqual(provider.requestCount, 2)
    }

    func testRefreshFailurePreservesExistingPlacesAndReportsError() async throws {
        let original = makePlace(id: "1", name: "Original")
        let provider = RefreshPOIProvider(outcomes: [
            .success([original]),
            .failure
        ])
        let model = CatalogueModel(provider: provider)

        await model.loadIfNeeded()
        await model.refresh()

        XCTAssertEqual(loadedPlaceIDs(in: model), ["1"])
        XCTAssertTrue(model.refreshError?.contains("Could not refresh places") == true)
        XCTAssertFalse(model.isRefreshing)
        XCTAssertEqual(provider.requestCount, 2)
    }

    func testRefreshShowsLoadingAndPreventsOverlappingRequests() async throws {
        let original = makePlace(id: "1", name: "Original")
        let updated = makePlace(id: "2", name: "Updated")
        let provider = RefreshPOIProvider(
            outcomes: [.success([original]), .success([updated])],
            delayNanoseconds: 80_000_000
        )
        let model = CatalogueModel(provider: provider)

        await model.loadIfNeeded()
        let refreshTask = Task { await model.refresh() }
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertTrue(model.isRefreshing)
        XCTAssertEqual(loadedPlaceIDs(in: model), ["1"])

        await model.refresh()
        XCTAssertEqual(provider.requestCount, 2)

        await refreshTask.value
        XCTAssertFalse(model.isRefreshing)
        XCTAssertEqual(loadedPlaceIDs(in: model), ["2"])
    }

    func testRefreshKeepsActiveSearchAndFiltersNewResults() async throws {
        let provider = RefreshPOIProvider(outcomes: [
            .success([makePlace(id: "1", name: "First")]),
            .success([
                makePlace(id: "2", name: "Second", address: "Market 1"),
                makePlace(id: "3", name: "Third", address: "Park 2")
            ])
        ])
        let model = CatalogueModel(provider: provider)

        await model.loadIfNeeded()
        model.searchText = "market"
        await model.refresh()

        XCTAssertEqual(model.searchText, "market")
        XCTAssertEqual(model.filteredPlaces.map(\.id), ["2"])
        XCTAssertEqual(provider.requestCount, 2)
    }

    func testRejectsUnsuccessfulHTTPStatus() async throws {
        let service = makeService(statusCode: 503, body: Data())

        do {
            _ = try await service.fetchPointsOfInterest()
            XCTFail("Expected an HTTP status error.")
        } catch let error as ViennaPOIServiceError {
            XCTAssertEqual(error, .httpStatusCode(503))
        }
    }

    func testRejectsMalformedJSON() async throws {
        let service = makeService(statusCode: 200, body: Data("not JSON".utf8))

        do {
            _ = try await service.fetchPointsOfInterest()
            XCTFail("Expected a malformed-response error.")
        } catch let error as ViennaPOIServiceError {
            XCTAssertEqual(error, .malformedResponse)
        }
    }

    func testSkipsFeatureWithInvalidCoordinates() async throws {
        let invalidFeatureCollection = try XCTUnwrap(
            String(data: sourceFixture(), encoding: .utf8)
        ).replacingOccurrences(
            of: "\"coordinates\": [16.37367575, 48.21076056]",
            with: "\"coordinates\": [181, 48.21076056]"
        )
        let service = makeService(
            statusCode: 200,
            body: Data(invalidFeatureCollection.utf8)
        )

        let places = try await service.fetchPointsOfInterest()
        XCTAssertEqual(places.map(\.id), ["SEHENSWUERDIGOGD.640964"])
    }

    func testSkipsFeatureWithMalformedCoordinateRepresentation() async throws {
        let sampleWithMalformedCoordinates = try XCTUnwrap(
            String(data: sourceFixture(), encoding: .utf8)
        ).replacingOccurrences(
            of: "\"coordinates\": [16.40167012, 48.18297383]",
            with: "\"coordinates\": [\"unknown\", 48.18297383]"
        )
        let service = makeService(
            statusCode: 200,
            body: Data(sampleWithMalformedCoordinates.utf8)
        )

        let places = try await service.fetchPointsOfInterest()

        XCTAssertEqual(places.map(\.id), ["SEHENSWUERDIGOGD.640963"])
    }

    func testRejectsCollectionWhenNoFeatureCanBeDisplayed() async throws {
        let sampleWithoutDisplayableCoordinates = try XCTUnwrap(
            String(data: sourceFixture(), encoding: .utf8)
        )
        .replacingOccurrences(
            of: "\"coordinates\": [16.37367575, 48.21076056]",
            with: "\"coordinates\": [181, 48.21076056]"
        )
        .replacingOccurrences(
            of: "\"coordinates\": [16.40167012, 48.18297383]",
            with: "\"coordinates\": [181, 48.18297383]"
        )
        let service = makeService(
            statusCode: 200,
            body: Data(sampleWithoutDisplayableCoordinates.utf8)
        )

        do {
            _ = try await service.fetchPointsOfInterest()
            XCTFail("Expected a malformed-response error.")
        } catch let error as ViennaPOIServiceError {
            XCTAssertEqual(error, .malformedResponse)
        }
    }

    func testUsesObjectIDWhenFeatureIdentifierIsMissing() async throws {
        let sampleWithoutFeatureID = try XCTUnwrap(
            String(data: sourceFixture(), encoding: .utf8)
        ).replacingOccurrences(of: "\"id\": \"SEHENSWUERDIGOGD.640963\",\n", with: "")
        let service = makeService(statusCode: 200, body: Data(sampleWithoutFeatureID.utf8))

        let places = try await service.fetchPointsOfInterest()

        XCTAssertEqual(places.first?.id, "640963")
    }

    func testMissingOptionalAttributesDoNotDiscardPlace() async throws {
        let sampleWithoutOptionalAttributes = try XCTUnwrap(
            String(data: sourceFixture(), encoding: .utf8)
        )
        .replacingOccurrences(of: "\"ADRESSE\": \"Hoher Markt 10/\",\n", with: "")
        .replacingOccurrences(
            of: "\"WEITERE_INF\": \"http://www.wien.info/article.asp?IDArticle=2018\",\n",
            with: ""
        )
        .replacingOccurrences(
            of: "\"THUMBNAIL\": \"https://www.wien.gv.at/viennagis/bubble/ankeruhr.jpg\",\n",
            with: ""
        )
        let service = makeService(
            statusCode: 200,
            body: Data(sampleWithoutOptionalAttributes.utf8)
        )

        let places = try await service.fetchPointsOfInterest()

        XCTAssertEqual(places.first?.name, "Ankeruhr")
        XCTAssertNil(places.first?.address)
        XCTAssertNil(places.first?.informationURL)
        XCTAssertNil(places.first?.thumbnailURL)
    }

    func testInvalidOptionalURLIsIgnored() async throws {
        let sampleWithInvalidThumbnail = try XCTUnwrap(
            String(data: sourceFixture(), encoding: .utf8)
        ).replacingOccurrences(
            of: "\"THUMBNAIL\": \"https://www.wien.gv.at/viennagis/bubble/ankeruhr.jpg\"",
            with: "\"THUMBNAIL\": \"javascript:alert(1)\""
        )
        let service = makeService(
            statusCode: 200,
            body: Data(sampleWithInvalidThumbnail.utf8)
        )

        let places = try await service.fetchPointsOfInterest()

        XCTAssertEqual(places.first?.name, "Ankeruhr")
        XCTAssertNil(places.first?.thumbnailURL)
    }

    func testPropagatesCancellation() async throws {
        let service = ViennaPOIService { _ in
            throw CancellationError()
        }

        do {
            _ = try await service.fetchPointsOfInterest()
            XCTFail("Expected cancellation to propagate.")
        } catch is CancellationError {
            // Expected: callers retain control over task cancellation.
        }
    }

    func testPropagatesNetworkFailure() async throws {
        let service = ViennaPOIService { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await service.fetchPointsOfInterest()
            XCTFail("Expected the network error to propagate.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }
    }

    private func makeService(statusCode: Int, body: Data) -> ViennaPOIService {
        let expectedEndpoint = ViennaPOIService.endpoint
        return ViennaPOIService { request in
            guard request.url == expectedEndpoint,
                  request.value(forHTTPHeaderField: "Accept") == "application/json",
                  let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                  )
            else {
                throw URLError(.badURL)
            }
            return (body, response)
        }
    }

    private func sourceFixture() throws -> Data {
        let fixtureURL = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "vienna-sights-sample",
                withExtension: "json"
            )
        )
        return try Data(contentsOf: fixtureURL)
    }

    private func loadedPlaceIDs(in model: CatalogueModel) -> [String]? {
        guard case .loaded(let places) = model.state else {
            XCTFail("Expected the catalogue to retain loaded places.")
            return nil
        }
        return places.map(\.id)
    }

    private func makePlace(
        id: String,
        name: String,
        address: String? = nil
    ) -> PointOfInterest {
        PointOfInterest(
            id: id,
            name: name,
            address: address,
            informationURL: nil,
            thumbnailURL: nil,
            latitude: 48.2,
            longitude: 16.3
        )
    }

    private func temporarySavedPlacesFile() -> (directory: URL, file: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("POIExplorerTests-\(UUID().uuidString)", isDirectory: true)
        return (directory, directory.appendingPathComponent("SavedPOIs.json"))
    }

    @MainActor
    private final class CountingPOIProvider: PointOfInterestProviding {
        private let places: [PointOfInterest]
        private(set) var requestCount = 0

        init(places: [PointOfInterest]) {
            self.places = places
        }

        func fetchPointsOfInterest() async throws -> [PointOfInterest] {
            requestCount += 1
            return places
        }
    }

    @MainActor
    private final class RefreshPOIProvider: PointOfInterestProviding {
        enum Outcome {
            case success([PointOfInterest])
            case failure
        }

        private let outcomes: [Outcome]
        private let delayNanoseconds: UInt64
        private(set) var requestCount = 0

        init(outcomes: [Outcome], delayNanoseconds: UInt64 = 0) {
            self.outcomes = outcomes
            self.delayNanoseconds = delayNanoseconds
        }

        func fetchPointsOfInterest() async throws -> [PointOfInterest] {
            let requestIndex = requestCount
            requestCount += 1
            if delayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard outcomes.indices.contains(requestIndex) else {
                throw URLError(.resourceUnavailable)
            }
            switch outcomes[requestIndex] {
            case .success(let places):
                return places
            case .failure:
                throw URLError(.notConnectedToInternet)
            }
        }
    }
}

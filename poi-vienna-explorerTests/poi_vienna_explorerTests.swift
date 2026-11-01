import Foundation
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
}

import Foundation
import XCTest
@testable import poi_vienna_explorer

@MainActor
final class poi_vienna_explorerTests: XCTestCase {
    func testFetchMapsGeoJSONIntoPlaceModels() async throws {
        let service = makeService(statusCode: 200, body: Data(validFeatureCollection.utf8))

        let places = try await service.fetchPointsOfInterest()

        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places[0].id, "SEHENSWUERDIGOGD.640963")
        XCTAssertEqual(places[0].name, "Ankeruhr")
        XCTAssertEqual(places[0].address, "Hoher Markt 10/")
        XCTAssertEqual(places[0].latitude, 48.21076056)
        XCTAssertEqual(places[0].longitude, 16.37367575)
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

    func testRejectsInvalidCoordinates() async throws {
        let invalidFeatureCollection = validFeatureCollection.replacingOccurrences(
            of: "\"coordinates\": [16.37367575, 48.21076056]",
            with: "\"coordinates\": [181, 48.21076056]"
        )
        let service = makeService(
            statusCode: 200,
            body: Data(invalidFeatureCollection.utf8)
        )

        do {
            _ = try await service.fetchPointsOfInterest()
            XCTFail("Expected a malformed-response error.")
        } catch let error as ViennaPOIServiceError {
            XCTAssertEqual(error, .malformedResponse)
        }
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

    private let validFeatureCollection = """
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "id": "SEHENSWUERDIGOGD.640963",
          "geometry": {
            "type": "Point",
            "coordinates": [16.37367575, 48.21076056]
          },
          "properties": {
            "NAME": "Ankeruhr",
            "ADRESSE": "Hoher Markt 10/"
          }
        }
      ]
    }
    """
}

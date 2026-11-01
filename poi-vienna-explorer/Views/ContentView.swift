//
//  ContentView.swift
//  poi-vienna-explorer
//
//  Created by Isiaka Mosudi on 01.11.26.
//

import MapKit
import SwiftUI

struct ContentView: View {
    @State private var catalogue = CatalogueModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image("BrandingHeaderBanner")
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("Vienna POI Explorer. Discover. Explore. Save.")

                    NavigationLink {
                        POICatalogueView(catalogue: catalogue)
                    } label: {
                        Image("BrandingPromoCard")
                            .resizable()
                            .scaledToFit()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Browse places in Vienna")

                    Image("BrandingCityWienOpenDataBadge")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 360)
                        .accessibilityLabel("City of Vienna Open Government Data")
                }
                .frame(maxWidth: 680)
                .padding()
            }
            .navigationTitle("Explore Vienna")
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                CopyrightFooter()
            }
        }
        .task {
            await catalogue.loadIfNeeded()
        }
    }
}

private struct POICatalogueView: View {
    @Bindable var catalogue: CatalogueModel

    var body: some View {
        catalogueContent
            .navigationTitle("Vienna sights")
            .searchable(text: $catalogue.searchText, prompt: "Name, address, or website")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await catalogue.refresh()
                        }
                    } label: {
                        if catalogue.isRefreshing {
                            ProgressView()
                                .accessibilityLabel("Refreshing places")
                        } else {
                            Label {
                                Text("Refresh")
                            } icon: {
                                Image("IconsRefresh")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                            }
                        }
                    }
                    .disabled(catalogue.isRefreshing || !catalogue.hasLoadedPlaces)
                }
            }
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                CopyrightFooter()
            }
    }

    @ViewBuilder
    private var catalogueContent: some View {
        switch catalogue.state {
        case .idle, .loading:
            ProgressView("Loading places")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let places):
            VStack(spacing: 0) {
                if let refreshError = catalogue.refreshError {
                    Label(refreshError, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .accessibilityIdentifier("catalogue-refresh-error")
                }

                if places.isEmpty {
                    ContentUnavailableView(
                        "No places found",
                        systemImage: "map",
                        description: Text("There are no Vienna sights to show right now.")
                    )
                } else if catalogue.filteredPlaces.isEmpty {
                    ContentUnavailableView.search(text: catalogue.searchText)
                } else {
                    List(catalogue.filteredPlaces) { place in
                        NavigationLink {
                            POIMapView(selectedPOI: place, places: places)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(place.name)
                                    .font(.headline)

                                if let address = place.address {
                                    Label(address, systemImage: "mappin")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .padding(.vertical, 6)
                    }
                    .listStyle(.plain)
                    .scrollIndicators(.visible, axes: .vertical)
                    .refreshable {
                        await catalogue.refresh()
                    }
                }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Places could not be loaded", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task {
                        await catalogue.retry()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct CopyrightFooter: View {
    var body: some View {
        Text("Mosudi Isiaka O., FHTW © 2026")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea(edges: .bottom)
            }
    }
}

private struct POIMapView: View {
    let selectedPOI: PointOfInterest
    let places: [PointOfInterest]
    @State private var selectedAnnotation: POIAnnotationDetails?
    @StateObject private var locationService = UserLocationService()
    @State private var mapPosition: MapCameraPosition

    init(selectedPOI: PointOfInterest, places: [PointOfInterest]) {
        self.selectedPOI = selectedPOI
        self.places = places
        _selectedAnnotation = State(
            initialValue: POIAnnotationDetails(pointOfInterest: selectedPOI)
        )
        _mapPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: selectedPOI.latitude,
                        longitude: selectedPOI.longitude
                    ),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        )
    }

    private var coordinate: CLLocationCoordinate2D? {
        let latitude = selectedPOI.latitude
        let longitude = selectedPOI.longitude

        guard latitude.isFinite,
              longitude.isFinite,
              (-90...90).contains(latitude),
              (-180...180).contains(longitude)
        else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        Group {
            if let coordinate {
                Map(
                    selection: $selectedAnnotation,
                    position: $mapPosition
                ) {
                    if locationService.isAuthorized {
                        UserAnnotation()
                    }

                    ForEach(places) { place in
                        let annotation = POIAnnotationDetails(pointOfInterest: place)
                        let annotationCoordinate = CLLocationCoordinate2D(
                            latitude: annotation.latitude,
                            longitude: annotation.longitude
                        )
                        let distanceText = distanceText(to: place)
                        let markerStyle = POIMarkerStyle(pointOfInterest: place)
                        let isSelected = selectedAnnotation?.id == annotation.id

                        Annotation(
                            annotation.name,
                            coordinate: annotationCoordinate,
                            anchor: .bottom
                        ) {
                            POIMapAnnotationView(
                                details: annotation,
                                markerStyle: markerStyle,
                                isSelected: isSelected,
                                distanceText: distanceText
                            )
                        }
                        .annotationTitles(.hidden)
                        .tag(annotation)
                    }
                }
                .overlay(alignment: .top) {
                    if let statusMessage = locationService.statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .padding()
                            .accessibilityIdentifier("location-status")
                    }
                }
                .onAppear {
                    locationService.requestLocationWhenInUseIfNeeded()
                }
                .onDisappear {
                    locationService.stopUpdatingLocation()
                }
            } else {
                ContentUnavailableView(
                    "Location unavailable",
                    systemImage: "mappin.slash",
                    description: Text("This place does not have valid map coordinates.")
                )
            }
        }
        .navigationTitle(selectedPOI.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func distanceText(to place: PointOfInterest) -> String? {
        guard let location = locationService.location,
              let meters = POIDistanceCalculator.distanceMeters(
                from: location.coordinate,
                to: place
              )
        else {
            return nil
        }
        return POIDistanceFormatter.formattedDistance(meters: meters)
    }
}

private struct POIMapAnnotationView: View {
    let details: POIAnnotationDetails
    let markerStyle: POIMarkerStyle
    let isSelected: Bool
    let distanceText: String?

    private var accessibilityLabel: String {
        details.name + ", " + markerStyle.accessibilityDescription
    }

    var body: some View {
        VStack(spacing: 4) {
            if isSelected {
                POIAnnotationCallout(details: details, distanceText: distanceText)
            }

            POIMarkerView(style: markerStyle, isSelected: isSelected)
                .accessibilityLabel(Text(accessibilityLabel))
        }
        .contentShape(Rectangle())
        .accessibilityIdentifier("poi-annotation-\(details.id)")
    }
}

private struct POIMarkerView: View {
    let style: POIMarkerStyle
    let isSelected: Bool

    private var markerColor: Color {
        switch style {
        case .informationLink:
            .blue
        case .neutral:
            .gray
        }
    }

    var body: some View {
        Image(systemName: "mappin")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(markerColor, in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(.white, lineWidth: isSelected ? 3 : 1)
            }
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .scaleEffect(isSelected ? 1.15 : 1)
    }
}

private struct POIAnnotationCallout: View {
    let details: POIAnnotationDetails
    let distanceText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(details.name)
                .font(.headline)

            if let address = details.address {
                Label(address, systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let distanceText {
                Label("\(distanceText) away", systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("poi-distance-\(details.id)")
            }

            if let thumbnailURL = details.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .accessibilityHidden(true)
            }

            if let informationURL = details.informationURL {
                Link(destination: informationURL) {
                    Image("UI_MoreDetailsButton")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 190)
                }
                .accessibilityLabel("More information about \(details.name)")
            }
        }
        .frame(maxWidth: 240, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .shadow(radius: 4)
        .accessibilityIdentifier("poi-callout-\(details.id)")
    }
}

#Preview {
    ContentView()
}

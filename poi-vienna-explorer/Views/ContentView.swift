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
            VStack(spacing: 20) {
                Spacer()

                ContentUnavailableView(
                    "Vienna POI Explorer",
                    systemImage: "map",
                    description: Text("Your guide to Vienna is coming soon.")
                )

                NavigationLink {
                    POICatalogueView(catalogue: catalogue)
                } label: {
                    Label("Browse places", systemImage: "list.bullet")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)

                Spacer()
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
                            Label("Refresh", systemImage: "arrow.clockwise")
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

    init(selectedPOI: PointOfInterest, places: [PointOfInterest]) {
        self.selectedPOI = selectedPOI
        self.places = places
        _selectedAnnotation = State(
            initialValue: POIAnnotationDetails(pointOfInterest: selectedPOI)
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
                    initialPosition: .region(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(
                                latitudeDelta: 0.01,
                                longitudeDelta: 0.01
                            )
                        )
                    ),
                    selection: $selectedAnnotation
                ) {
                    ForEach(places) { place in
                        let annotation = POIAnnotationDetails(pointOfInterest: place)
                        let annotationCoordinate = CLLocationCoordinate2D(
                            latitude: annotation.latitude,
                            longitude: annotation.longitude
                        )

                        Annotation(
                            annotation.name,
                            coordinate: annotationCoordinate,
                            anchor: .bottom
                        ) {
                            let markerStyle = POIMarkerStyle(pointOfInterest: place)
                            let isSelected = selectedAnnotation?.id == annotation.id

                            VStack(spacing: 4) {
                                if isSelected {
                                    POIAnnotationCallout(details: annotation)
                                }

                                POIMarkerView(style: markerStyle, isSelected: isSelected)
                                    .accessibilityLabel(
                                        "\(annotation.name), \(markerStyle.accessibilityDescription)"
                                    )
                            }
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("poi-annotation-\(annotation.id)")
                        }
                        .annotationTitles(.hidden)
                        .tag(annotation)
                    }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(details.name)
                .font(.headline)

            if let address = details.address {
                Label(address, systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                Link("More information", destination: informationURL)
                    .font(.subheadline)
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

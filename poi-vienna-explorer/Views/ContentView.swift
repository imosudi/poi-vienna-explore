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
    @State private var savedPlaces = SavedPlacesModel()
    @State private var selectedTab: ExplorerTab = .explore
    @State private var explorePath: [ExploreRoute] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $explorePath) {
                ExploreHomeView(
                    catalogue: catalogue,
                    onBrowsePlaces: { explorePath.append(.places) },
                    onOpenSavedPlaces: { selectedTab = .saved }
                )
                .navigationDestination(for: ExploreRoute.self) { destination in
                    switch destination {
                    case .places:
                        POICatalogueView(catalogue: catalogue, savedPlaces: savedPlaces)
                    }
                }
            }
            .tabItem { Label("Explore", systemImage: "safari") }
            .tag(ExplorerTab.explore)

            NavigationStack {
                AllPlacesMapView(catalogue: catalogue, savedPlaces: savedPlaces)
            }
            .tabItem { Label("Map", systemImage: "map") }
            .tag(ExplorerTab.map)

            NavigationStack {
                SavedPlacesView(
                    savedPlaces: savedPlaces,
                    places: catalogue.loadedPlaces
                )
            }
            .tabItem { Label("Saved", systemImage: "heart") }
            .tag(ExplorerTab.saved)
        }
        .tint(AppPalette.accent)
        .task {
            await catalogue.loadIfNeeded()
        }
        .alert(
            "Saved places",
            isPresented: Binding(
                get: { savedPlaces.errorMessage != nil },
                set: { if !$0 { savedPlaces.clearError() } }
            )
        ) {
            Button("OK") {
                savedPlaces.clearError()
            }
        } message: {
            Text(savedPlaces.errorMessage ?? "An unknown persistence error occurred.")
        }
    }
}

private enum ExplorerTab: Hashable {
    case explore
    case map
    case saved
}

private enum ExploreRoute: Hashable {
    case places
}

private enum AppPalette {
    static let canvas = Color(red: 0.98, green: 0.97, blue: 0.95)
    static let ink = Color(red: 0.08, green: 0.15, blue: 0.29)
    static let accent = Color(red: 0.82, green: 0.04, blue: 0.16)
}

private struct ExploreHomeView: View {
    @Bindable var catalogue: CatalogueModel
    let onBrowsePlaces: () -> Void
    let onOpenSavedPlaces: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image("BrandingHeaderBanner")
                    .resizable()
                    .scaledToFit()
                    .modifier(HoverGiggleEffect())
                    .accessibilityLabel("Vienna POI Explorer. Discover. Explore. Save.")

                searchField
                quickFilters

                Button(action: onBrowsePlaces) {
                    Image("BrandingPromoCard")
                        .resizable()
                        .scaledToFit()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Browse places in Vienna")

                Button(action: onOpenSavedPlaces) {
                    Label("Saved places", systemImage: "heart.fill")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background(.white, in: RoundedRectangle(cornerRadius: 24))
                }
                .buttonStyle(.plain)

                Image("BrandingCityWienOpenDataBadge")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360)
                    .accessibilityLabel("City of Vienna Open Government Data")
            }
            .frame(maxWidth: 680)
            .padding()
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(AppPalette.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image("IconsSearch")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)

            TextField("Name, address, or website", text: $catalogue.searchText)
                .submitLabel(.search)
                .onSubmit(onBrowsePlaces)
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
    }

    private var quickFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CatalogueModel.QuickFilter.allCases) { filter in
                    Button {
                        catalogue.quickFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.headline)
                            .foregroundStyle(
                                catalogue.quickFilter == filter ? .white : AppPalette.ink
                            )
                            .padding(.horizontal, 20)
                            .frame(height: 46)
                            .background(
                                catalogue.quickFilter == filter ? AppPalette.accent : .white,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityLabel("Filter places")
    }
}

private struct HoverGiggleEffect: ViewModifier {
    @State private var rotation = 0.0
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .rotationEffect(.degrees(rotation))
            .hoverEffect(.highlight)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    guard !isHovered else { return }
                    isHovered = true
                    withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                        rotation = 5
                    }
                case .ended:
                    guard isHovered else { return }
                    isHovered = false
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        rotation = 0
                    }
                }
            }
    }
}

private struct POICatalogueView: View {
    @Bindable var catalogue: CatalogueModel
    @Bindable var savedPlaces: SavedPlacesModel

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal)
                .padding(.bottom, 8)

            catalogueContent
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .navigationTitle("Places")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Places")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppPalette.ink)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Image("BrandingAppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                        .accessibilityHidden(true)

                    Button {
                        Task {
                            await catalogue.refresh()
                        }
                    } label: {
                        if catalogue.isRefreshing {
                            ProgressView()
                                .accessibilityLabel("Refreshing places")
                        } else {
                            Image("IconsRefresh")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                        }
                    }
                    .disabled(catalogue.isRefreshing || !catalogue.hasLoadedPlaces)
                }
            }
            .toolbarBackground(AppPalette.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                CopyrightFooter()
            }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image("IconsSearch")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)

            TextField("Name, address, or website", text: $catalogue.searchText)
                .submitLabel(.search)
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
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
                    if catalogue.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView(
                            "No matching places",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text(
                                catalogue.quickFilter == .withAddress
                                    ? "No places with an address are available."
                                    : "No places with an information website are available."
                            )
                        )
                    } else {
                        ContentUnavailableView.search(text: catalogue.searchText)
                    }
                } else {
                    List(catalogue.filteredPlaces) { place in
                        HStack(spacing: 10) {
                            NavigationLink {
                                POIMapView(
                                    selectedPOI: place,
                                    places: places,
                                    savedPlaces: savedPlaces
                                )
                            } label: {
                                HStack(spacing: 14) {
                                    Image("IconsMapPin")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 52, height: 52)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(place.name)
                                            .font(.headline)
                                            .foregroundStyle(AppPalette.ink)

                                        if let address = place.address {
                                            Text(address)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            FavoritePlaceButton(place: place, savedPlaces: savedPlaces)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(AppPalette.canvas)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
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

private struct FavoritePlaceButton: View {
    let place: PointOfInterest
    @Bindable var savedPlaces: SavedPlacesModel

    var body: some View {
        Button {
            if savedPlaces.contains(place) {
                savedPlaces.remove(place)
            } else {
                savedPlaces.save(place)
            }
        } label: {
            Image(systemName: savedPlaces.contains(place) ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(savedPlaces.contains(place) ? AppPalette.accent : .secondary)
                .frame(width: 44, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(savedPlaces.contains(place) ? "Remove saved place" : "Save place")
        .accessibilityIdentifier("save-poi-\(place.id)")
    }
}

private struct SavedPlacesView: View {
    @Bindable var savedPlaces: SavedPlacesModel
    let places: [PointOfInterest]

    var body: some View {
        Group {
            if savedPlaces.places.isEmpty {
                ContentUnavailableView(
                    "No saved places",
                    systemImage: "heart",
                    description: Text("Save a place from its map to find it here.")
                )
            } else {
                List {
                    ForEach(savedPlaces.places) { place in
                        NavigationLink {
                            POIMapView(
                                selectedPOI: place,
                                places: places.isEmpty ? savedPlaces.places : places,
                                savedPlaces: savedPlaces
                            )
                        } label: {
                            PlaceRow(
                                place: place,
                                places: places,
                                savedPlaces: savedPlaces
                            )
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                savedPlaces.remove(place)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppPalette.canvas)
            }
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .navigationTitle("Saved")
        .toolbarBackground(AppPalette.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct PlaceRow: View {
    let place: PointOfInterest
    let places: [PointOfInterest]
    @Bindable var savedPlaces: SavedPlacesModel

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink {
                POIMapView(
                    selectedPOI: place,
                    places: places.isEmpty ? savedPlaces.places : places,
                    savedPlaces: savedPlaces
                )
            } label: {
                HStack(spacing: 14) {
                    Image("IconsMapPin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.headline)
                            .foregroundStyle(AppPalette.ink)

                        if let address = place.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            FavoritePlaceButton(place: place, savedPlaces: savedPlaces)
        }
        .padding(.vertical, 6)
        .listRowBackground(AppPalette.canvas)
    }
}

private struct AllPlacesMapView: View {
    @Bindable var catalogue: CatalogueModel
    @Bindable var savedPlaces: SavedPlacesModel

    var body: some View {
        Group {
            switch catalogue.state {
            case .idle, .loading:
                ProgressView("Loading places")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Places could not be loaded", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                }
            case .loaded(let places) where places.isEmpty:
                ContentUnavailableView("No places found", systemImage: "map")
            case .loaded(let places):
                AllPOIMap(places: places, savedPlaces: savedPlaces)
            }
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .navigationTitle("Map")
        .toolbarBackground(AppPalette.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct AllPOIMap: View {
    let places: [PointOfInterest]
    @Bindable var savedPlaces: SavedPlacesModel
    @State private var selectedAnnotation: POIAnnotationDetails?
    @State private var mapPosition: MapCameraPosition
    @StateObject private var locationService = UserLocationService()

    init(places: [PointOfInterest], savedPlaces: SavedPlacesModel) {
        self.places = places
        self.savedPlaces = savedPlaces
        let initialPosition: MapCameraPosition
        if let place = places.first {
            initialPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: place.latitude,
                        longitude: place.longitude
                    ),
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
        } else {
            initialPosition = .automatic
        }
        _mapPosition = State(initialValue: initialPosition)
    }

    var body: some View {
        Map(position: $mapPosition, selection: $selectedAnnotation) {
            if locationService.isAuthorized {
                UserAnnotation()
            }

            ForEach(places) { place in
                let details = POIAnnotationDetails(pointOfInterest: place)
                let distance = distanceText(to: place)
                let markerStyle = POIMarkerStyle(pointOfInterest: place)
                let isSelected = selectedAnnotation?.id == place.id

                Annotation(
                    place.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: place.latitude,
                        longitude: place.longitude
                    ),
                    anchor: .bottom
                ) {
                    POIMapAnnotationView(
                        details: details,
                        markerStyle: markerStyle,
                        isSelected: isSelected,
                        distanceText: distance
                    )
                }
                .annotationTitles(.hidden)
                .tag(details)
            }
        }
        .overlay(alignment: .top) {
            if let message = locationService.statusMessage {
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding()
            }
        }
        .overlay(alignment: .topTrailing) {
            if let selectedPlace {
                FavoritePlaceButton(place: selectedPlace, savedPlaces: savedPlaces)
                    .background(.regularMaterial, in: Circle())
                    .padding()
                    .padding(.top, 44)
            }
        }
        .onAppear {
            locationService.requestLocationWhenInUseIfNeeded()
        }
        .onDisappear {
            locationService.stopUpdatingLocation()
        }
    }

    private var selectedPlace: PointOfInterest? {
        guard let id = selectedAnnotation?.id else { return nil }
        return places.first(where: { $0.id == id })
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

private struct CopyrightFooter: View {
    var body: some View {
        Text("Mosudi Isiaka O., FHTW © 2026")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                AppPalette.canvas
                    .ignoresSafeArea(edges: .bottom)
            }
    }
}

private struct POIMapView: View {
    let selectedPOI: PointOfInterest
    let places: [PointOfInterest]
    @Bindable var savedPlaces: SavedPlacesModel
    @State private var selectedAnnotation: POIAnnotationDetails?
    @StateObject private var locationService = UserLocationService()
    @State private var mapPosition: MapCameraPosition

    init(
        selectedPOI: PointOfInterest,
        places: [PointOfInterest],
        savedPlaces: SavedPlacesModel
    ) {
        self.selectedPOI = selectedPOI
        self.places = places
        self.savedPlaces = savedPlaces
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
            if coordinate != nil {
                Map(
                    position: $mapPosition,
                    selection: $selectedAnnotation
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if savedPlaces.contains(selectedPOI) {
                        savedPlaces.remove(selectedPOI)
                    } else {
                        savedPlaces.save(selectedPOI)
                    }
                } label: {
                    Label(
                        savedPlaces.contains(selectedPOI) ? "Remove saved place" : "Save place",
                        systemImage: savedPlaces.contains(selectedPOI) ? "heart.fill" : "heart"
                    )
                }
                .accessibilityIdentifier("save-poi-\(selectedPOI.id)")
            }
        }
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
                    }
                }
                .frame(width: 216, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            }

            if let informationURL = details.informationURL {
                Link("More information", destination: informationURL)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 2)
                    .accessibilityIdentifier("poi-information-link-\(details.id)")
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

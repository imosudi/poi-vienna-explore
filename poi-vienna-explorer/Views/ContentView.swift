//
//  ContentView.swift
//  poi-vienna-explorer
//
//  Created by Isiaka Mosudi on 01.11.26.
//

import SwiftUI

struct ContentView: View {
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
                    POICatalogueView()
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
    }
}

private struct POICatalogueView: View {
    @State private var catalogue = CatalogueModel()

    var body: some View {
        catalogueContent
            .navigationTitle("Vienna sights")
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                CopyrightFooter()
            }
            .task {
                await catalogue.loadIfNeeded()
            }
    }

    @ViewBuilder
    private var catalogueContent: some View {
        switch catalogue.state {
        case .idle, .loading:
            ProgressView("Loading places")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let places):
            if places.isEmpty {
                ContentUnavailableView(
                    "No places found",
                    systemImage: "map",
                    description: Text("There are no Vienna sights to show right now.")
                )
            } else {
                List(places) { place in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.name)
                            .font(.headline)

                        if let address = place.address {
                            Label(address, systemImage: "mappin")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let informationURL = place.informationURL {
                            Link("More information", destination: informationURL)
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.plain)
                .scrollIndicators(.visible, axes: .vertical)
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

#Preview {
    ContentView()
}

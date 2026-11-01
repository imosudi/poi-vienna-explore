//
//  ContentView.swift
//  poi-vienna-explorer
//
//  Created by Isiaka Mosudi on 01.11.26.
//

import SwiftUI

struct ContentView: View {
    @State private var catalogue = CatalogueModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ContentUnavailableView(
                    "Vienna POI Explorer",
                    systemImage: "map",
                    description: Text("Your guide to Vienna is coming soon.")
                )

                catalogueStatus
                    .padding(.bottom, 12)
            }
            .navigationTitle("Explore Vienna")
            .safeAreaInset(edge: .bottom) {
                Text("Mosudi Isiaka O., FHTW © 2026")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .task {
                await catalogue.loadIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var catalogueStatus: some View {
        switch catalogue.state {
        case .idle, .loading:
            ProgressView("Loading Vienna places")
        case .loaded(let places):
            Label("\(places.count) places loaded", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .failed(let message):
            VStack(spacing: 8) {
                Text(message)
                    .foregroundStyle(.secondary)
                Button("Try again") {
                    Task {
                        await catalogue.retry()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

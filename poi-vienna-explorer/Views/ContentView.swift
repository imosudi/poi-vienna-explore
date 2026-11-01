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
            ContentUnavailableView(
                "Vienna POI Explorer",
                systemImage: "map",
                description: Text("Your guide to Vienna is coming soon.")
            )
            .safeAreaInset(edge: .bottom) {
                Text("Mosudi Isiaka O., FHTW © 2026")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .navigationTitle("Explore Vienna")
        }
    }
}

#Preview {
    ContentView()
}

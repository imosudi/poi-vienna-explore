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
            .navigationTitle("Explore Vienna")
        }
    }
}

#Preview {
    ContentView()
}

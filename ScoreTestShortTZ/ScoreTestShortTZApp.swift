//
//  ScoreTestShortTZApp.swift
//  ScoreTestShortTZ
//
//  Created by John Sorren on 01.11.2025.
//

import SwiftUI

@main
struct ScoreTestShortTZApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

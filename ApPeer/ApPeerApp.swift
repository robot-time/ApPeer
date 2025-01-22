//
//  ApPeerApp.swift
//  ApPeer
//
//  Created by Miles Hedrick on 22/1/25.
//

import SwiftUI

@main
struct ApPeerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

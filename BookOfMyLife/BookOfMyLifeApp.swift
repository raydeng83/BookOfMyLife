//
//  BookOfMyLifeApp.swift
//  BookOfMyLife
//
//  Created by Le Deng on 1/20/26.
//

import SwiftUI

@main
struct BookOfMyLifeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

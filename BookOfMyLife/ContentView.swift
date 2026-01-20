//
//  ContentView.swift
//  BookOfMyLife
//
//  Created by Le Deng on 1/20/26.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
                .tag(0)
                .environment(\.managedObjectContext, viewContext)

            MonthBookView()
                .tabItem {
                    Label("Month Book", systemImage: "calendar")
                }
                .tag(1)
                .environment(\.managedObjectContext, viewContext)

            YearBookView()
                .tabItem {
                    Label("Year Book", systemImage: "calendar.badge.clock")
                }
                .tag(2)
                .environment(\.managedObjectContext, viewContext)

            ProfileView()
                .tabItem {
                    Label("Me", systemImage: "person.fill")
                }
                .tag(3)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

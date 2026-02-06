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
        ZStack {
            // Main content
            contentView

            // Tab bar at bottom
            VStack {
                Spacer()
                customTabBar
            }
        }
        .edgesIgnoringSafeArea(.all)
        .ignoresSafeArea(.all)
    }

    var contentView: some View {
        Group {
            switch selectedTab {
            case 0:
                JournalView()
                    .environment(\.managedObjectContext, viewContext)
            case 1:
                MonthBookView()
                    .environment(\.managedObjectContext, viewContext)
            case 2:
                YearBookView()
                    .environment(\.managedObjectContext, viewContext)
            case 3:
                ProfileView()
                    .environment(\.managedObjectContext, viewContext)
            default:
                JournalView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    var customTabBar: some View {
        HStack(spacing: 0) {
            TabBarButton(title: "Journal", icon: "book.fill", tag: 0, selectedTab: $selectedTab)
            TabBarButton(title: "Month Book", icon: "calendar", tag: 1, selectedTab: $selectedTab)
            TabBarButton(title: "Year Book", icon: "calendar.badge.clock", tag: 2, selectedTab: $selectedTab)
            TabBarButton(title: "Me", icon: "person.fill", tag: 3, selectedTab: $selectedTab)
        }
        .frame(height: 49)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial)
    }

}

struct TabBarButton: View {
    let title: String
    let icon: String
    let tag: Int
    @Binding var selectedTab: Int

    var body: some View {
        Button(action: {
            selectedTab = tag
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(selectedTab == tag ? .accentColor : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

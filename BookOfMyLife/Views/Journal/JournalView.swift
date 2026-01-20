//
//  JournalView.swift
//  BookOfMyLife
//
//  Main journal view with calendar and daily entry editor
//

import SwiftUI
import CoreData

struct JournalView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedDate = Date()
    @State private var showingEntryEditor = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DailyDigest.date, ascending: false)],
        animation: .default)
    private var allDigests: FetchedResults<DailyDigest>

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CalendarHeaderView(selectedDate: $selectedDate)
                    .padding()

                JournalCalendarView(
                    selectedDate: $selectedDate,
                    digestDates: digestDates
                )
                .padding(.horizontal)

                Divider()

                if let digest = digestForDate(selectedDate) {
                    DailyEntryDetailView(digest: digest)
                        .environment(\.managedObjectContext, viewContext)
                } else {
                    EmptyDayView(date: selectedDate)
                }

                Spacer()
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEntryEditor = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingEntryEditor) {
                DailyEntryEditorView(date: selectedDate)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private var digestDates: Set<Date> {
        Set(allDigests.compactMap { digest in
            guard let date = digest.date else { return nil }
            return Calendar.current.startOfDay(for: date)
        })
    }

    private func digestForDate(_ date: Date) -> DailyDigest? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return allDigests.first { digest in
            guard let digestDate = digest.date else { return false }
            return digestDate >= startOfDay && digestDate < endOfDay
        }
    }
}

#Preview {
    JournalView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

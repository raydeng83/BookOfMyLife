//
//  YearBookView.swift
//  BookOfMyLife
//
//  Yearly summary view
//

import SwiftUI
import CoreData

struct YearBookView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedYear = Calendar.current.component(.year, from: Date())

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \YearlySummary.year, ascending: false)],
        animation: .default)
    private var yearlySummaries: FetchedResults<YearlySummary>

    private var currentSummary: YearlySummary? {
        yearlySummaries.first { $0.year == selectedYear }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                YearPickerView(selectedYear: $selectedYear)
                    .padding()

                Divider()

                if let summary = currentSummary {
                    YearlySummaryDetailView(summary: summary)
                        .environment(\.managedObjectContext, viewContext)
                } else {
                    EmptyYearView(
                        year: selectedYear,
                        onGenerate: generateYearlySummary
                    )
                }
            }
            .navigationTitle("Year Book")
        }
    }

    private func generateYearlySummary() {
        // Will be implemented with processor
        print("Generating yearly summary for \(selectedYear)")
    }
}

#Preview {
    YearBookView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

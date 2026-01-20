//
//  MonthBookView.swift
//  BookOfMyLife
//
//  Monthly summary view with pack generation
//

import SwiftUI
import CoreData

struct MonthBookView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MonthlyPack.year, ascending: false),
                         NSSortDescriptor(keyPath: \MonthlyPack.month, ascending: false)],
        animation: .default)
    private var monthlyPacks: FetchedResults<MonthlyPack>

    private var currentPack: MonthlyPack? {
        monthlyPacks.first { pack in
            pack.year == selectedYear && pack.month == selectedMonth
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                MonthYearPickerView(
                    selectedYear: $selectedYear,
                    selectedMonth: $selectedMonth
                )
                .padding()

                Divider()

                if let pack = currentPack {
                    MonthlyPackDetailView(pack: pack)
                        .environment(\.managedObjectContext, viewContext)
                } else {
                    EmptyMonthView(
                        year: selectedYear,
                        month: selectedMonth,
                        onGenerate: generateMonthlyPack
                    )
                }
            }
            .navigationTitle("Month Book")
        }
    }

    private func generateMonthlyPack() {
        // Will be implemented with processor
        print("Generating monthly pack for \(selectedYear)/\(selectedMonth)")
    }
}

#Preview {
    MonthBookView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

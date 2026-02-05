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
    @State private var isGenerating = false
    @State private var generationProgress = ""

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
        NavigationStack {
            VStack(spacing: 0) {
                MonthYearPickerView(
                    selectedYear: $selectedYear,
                    selectedMonth: $selectedMonth
                )
                .padding(.horizontal)
                .padding(.top, 8)

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
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isGenerating {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text(generationProgress)
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private func generateMonthlyPack() {
        isGenerating = true
        generationProgress = "Analyzing journal entries..."

        Task {
            let generator = MonthlyPackGenerator()

            await MainActor.run {
                generationProgress = "Generating AI summary..."
            }

            await generator.generateMonthlyPack(
                year: selectedYear,
                month: selectedMonth,
                context: viewContext
            )

            await MainActor.run {
                isGenerating = false
            }
        }
    }
}

#Preview {
    MonthBookView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

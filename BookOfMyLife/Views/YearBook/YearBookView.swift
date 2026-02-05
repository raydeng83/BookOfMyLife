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
    @State private var isGenerating = false
    @State private var generationProgress = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \YearlySummary.year, ascending: false)],
        animation: .default)
    private var yearlySummaries: FetchedResults<YearlySummary>

    private var currentSummary: YearlySummary? {
        yearlySummaries.first { $0.year == selectedYear }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                YearPickerView(selectedYear: $selectedYear)
                    .padding(.horizontal)
                    .padding(.top, 8)

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

    private func generateYearlySummary() {
        isGenerating = true
        generationProgress = "Collecting monthly summaries..."

        Task {
            let generator = YearlySummaryGenerator()

            await MainActor.run {
                generationProgress = "Generating yearly reflection..."
            }

            await generator.generateYearlySummary(
                year: selectedYear,
                context: viewContext
            )

            await MainActor.run {
                isGenerating = false
            }
        }
    }
}

#Preview {
    YearBookView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

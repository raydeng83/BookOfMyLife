//
//  MonthlyPackDetailView.swift
//  BookOfMyLife
//
//  Displays generated monthly pack with summary and stats
//

import SwiftUI
import CoreData

struct MonthlyPackDetailView: View {
    @ObservedObject var pack: MonthlyPack
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditor = false
    @State private var showingPDFViewer = false
    @State private var isRegenerating = false
    @State private var showingRegenerateConfirmation = false

    private var stats: MonthlyStats? {
        guard let statsData = pack.statsData else { return nil }
        return statsData.decoded()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let stats = stats {
                    MonthlyStatsCard(stats: stats)
                        .padding(.horizontal)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("AI Summary")
                            .font(.headline)

                        Spacer()

                        if let method = pack.generationMethod {
                            Label(
                                method == "foundationModels" ? "AI Generated" : "Template",
                                systemImage: method == "foundationModels" ? "sparkles" : "doc.text"
                            )
                            .font(.caption)
                            .foregroundColor(method == "foundationModels" ? .blue : .secondary)
                        }
                    }

                    if let summary = pack.userEditedText ?? pack.aiSummaryText {
                        Text(summary)
                            .lineSpacing(4)
                    } else {
                        Text("No summary generated yet")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding(.horizontal)

                if pack.pdfData != nil {
                    Button(action: { showingPDFViewer = true }) {
                        HStack {
                            Image(systemName: "doc.richtext")
                            Text("View PDF")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }

                Button(action: { showingEditor = true }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Summary")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Button(action: { showingRegenerateConfirmation = true }) {
                    HStack {
                        if isRegenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Regenerate Summary")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRegenerating ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isRegenerating)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingEditor) {
            MonthlyPackEditorView(pack: pack)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Regenerate Summary?", isPresented: $showingRegenerateConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Regenerate", role: .destructive) {
                Task {
                    await regenerateSummary()
                }
            }
        } message: {
            Text("This will generate a new AI summary based on your journal entries. Any unsaved edits will be lost.")
        }
    }

    @MainActor
    private func regenerateSummary() async {
        isRegenerating = true
        defer { isRegenerating = false }

        let generator = MonthlyPackGenerator()
        _ = await generator.generateMonthlyPack(
            year: Int(pack.year),
            month: Int(pack.month),
            context: viewContext
        )
    }
}

struct MonthlyStatsCard: View {
    let stats: MonthlyStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Statistics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatItem(label: "Days with Entries", value: "\(stats.daysWithEntries)/\(stats.totalDays)")
                StatItem(label: "Total Photos", value: "\(stats.totalPhotos)")
                StatItem(label: "Total Words", value: "\(stats.totalWords)")
                StatItem(label: "Longest Streak", value: "\(stats.longestStreak) days")
                StatItem(label: "Starred Days", value: "\(stats.starredDaysCount)")
            }

            if !stats.topThemes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Themes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(Array(stats.topThemes.sorted(by: { $0.value > $1.value }).prefix(3)), id: \.key) { theme, count in
                        HStack {
                            Text(theme)
                            Spacer()
                            Text("\(count)")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}

//
//  YearlySummaryDetailView.swift
//  BookOfMyLife
//
//  Displays yearly summary with stats
//

import SwiftUI
import CoreData

struct YearlySummaryDetailView: View {
    @ObservedObject var summary: YearlySummary
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditor = false
    @State private var showingPDFViewer = false

    private var stats: YearlyStats? {
        guard let statsData = summary.statsData else { return nil }
        return statsData.decoded()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let stats = stats {
                    YearlyStatsCard(stats: stats)
                        .padding(.horizontal)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Summary")
                        .font(.headline)

                    if let summaryText = summary.userEditedText ?? summary.aiSummaryText {
                        Text(summaryText)
                            .lineSpacing(4)
                    } else {
                        Text("No summary generated yet")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding(.horizontal)

                if summary.pdfData != nil {
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
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingEditor) {
            YearlySummaryEditorView(summary: summary)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

struct YearlyStatsCard: View {
    let stats: YearlyStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yearly Statistics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatItem(label: "Days with Entries", value: "\(stats.daysWithEntries)/\(stats.totalDays)")
                StatItem(label: "Total Photos", value: "\(stats.totalPhotos)")
                StatItem(label: "Total Words", value: "\(stats.totalWords)")
                StatItem(label: "Longest Streak", value: "\(stats.longestStreak) days")
                StatItem(label: "Months Completed", value: "\(stats.monthsCompleted)")
            }

            if !stats.topThemes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Themes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(Array(stats.topThemes.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { theme, count in
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

            if !stats.milestones.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Milestones")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(stats.milestones, id: \.self) { milestone in
                        Text("• \(milestone)")
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

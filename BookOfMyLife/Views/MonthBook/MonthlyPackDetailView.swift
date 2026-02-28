//
//  MonthlyPackDetailView.swift
//  BookOfMyLife
//
//  Displays generated monthly pack with summary and stats
//

import SwiftUI
import CoreData
import PDFKit

struct MonthlyPackDetailView: View {
    @ObservedObject var pack: MonthlyPack
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditor = false
    @State private var showingPDFViewer = false
    @State private var isRegenerating = false
    @State private var showingRegenerateConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPhotoViewer = false
    @State private var selectedPhotos: [PhotoInfo] = []
    var onDelete: (() -> Void)?

    private var stats: MonthlyStats? {
        guard let statsData = pack.statsData else { return nil }
        return statsData.decoded()
    }

    private var photos: [PhotoInfo] {
        guard let photosData = pack.selectedPhotosData else { return [] }
        return [PhotoInfo].decoded(from: photosData)
    }

    private var themePhotos: [ThemePhoto] {
        guard let data = pack.themePhotosData else { return [] }
        return [ThemePhoto].decoded(from: data)
    }

    /// Parse opening text from narrative
    private var openingText: String? {
        guard let summary = pack.userEditedText ?? pack.aiSummaryText else { return nil }
        if summary.contains("---OPENING---") {
            let parts = summary.components(separatedBy: "---OPENING---")
            if parts.count > 1 {
                let afterOpening = parts[1]
                if let endIndex = afterOpening.range(of: "---CLOSING---")?.lowerBound {
                    return String(afterOpening[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return afterOpening.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Fallback: use first paragraph
        let paragraphs = summary.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        return paragraphs.first
    }

    /// Parse closing text from narrative
    private var closingText: String? {
        guard let summary = pack.userEditedText ?? pack.aiSummaryText else { return nil }
        if summary.contains("---CLOSING---") {
            let parts = summary.components(separatedBy: "---CLOSING---")
            if parts.count > 1 {
                return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Fallback: use last paragraph if different from first
        let paragraphs = summary.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        if paragraphs.count > 1 {
            return paragraphs.last
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let stats = stats {
                    MonthlyStatsCard(stats: stats)
                        .padding(.horizontal)
                }

                Divider()

                // Magazine-style layout with photos interspersed
                VStack(alignment: .leading, spacing: 16) {
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
                    .padding(.horizontal)

                    if themePhotos.isEmpty && openingText == nil {
                        Text("No summary generated yet")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.horizontal)
                    } else {
                        // New Yorker style magazine layout
                        magazineContent
                    }
                }

                // PDF buttons
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

                Button(action: { generatePDF() }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text(pack.pdfData != nil ? "Regenerate PDF" : "Generate PDF")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

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

                Button(action: { showingDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Month Book")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .padding(.bottom, 100) // Extra space for bottom tab bar
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
        .alert("Delete Month Book?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMonthBook()
            }
        } message: {
            Text("This will permanently delete this month book and its summary. Your daily journal entries will not be affected.")
        }
        .fullScreenCover(isPresented: $showingPhotoViewer) {
            VerticalPhotoViewer(photos: selectedPhotos)
        }
        .sheet(isPresented: $showingPDFViewer) {
            if let pdfData = pack.pdfData {
                PDFViewerView(pdfData: pdfData)
            }
        }
    }

    private func generatePDF() {
        let generator = PDFGenerator()
        if let pdfData = generator.generateMonthlyPDF(pack: pack) {
            pack.pdfData = pdfData
            try? viewContext.save()
        }
    }

    // MARK: - New Yorker Style Magazine Layout

    /// Group themePhotos by their theme name, preserving order of first appearance
    private var groupedThemePhotos: [(groupName: String, photos: [ThemePhoto])] {
        var order: [String] = []
        var groups: [String: [ThemePhoto]] = [:]
        for tp in themePhotos {
            if groups[tp.theme] == nil {
                order.append(tp.theme)
            }
            groups[tp.theme, default: []].append(tp)
        }
        return order.compactMap { name in
            guard let photos = groups[name] else { return nil }
            return (groupName: name, photos: photos)
        }
    }

    @ViewBuilder
    private var magazineContent: some View {
        // Opening
        if let opening = openingText {
            Text(opening)
                .font(.title3)
                .fontWeight(.light)
                .italic()
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }

        // Story sections grouped by theme
        ForEach(Array(groupedThemePhotos.enumerated()), id: \.element.groupName) { groupIndex, group in
            // Group header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.groupName.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .tracking(1.5)

                    Text("\(group.photos.count) \(group.photos.count == 1 ? "moment" : "moments")")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, groupIndex > 0 ? 20 : 8)
            .padding(.bottom, 4)

            // Photos within this group
            ForEach(group.photos, id: \.id) { themePhoto in
                StorySection(
                    themePhoto: themePhoto,
                    onPhotoTap: {
                        selectedPhotos = themePhoto.photos
                        showingPhotoViewer = true
                    }
                )
            }
        }

        // Closing
        if let closing = closingText {
            Text(closing)
                .font(.title3)
                .fontWeight(.light)
                .italic()
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
        }
    }

    private func deleteMonthBook() {
        viewContext.delete(pack)

        do {
            try viewContext.save()
            onDelete?()
        } catch {
            print("Error deleting month book: \(error)")
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

// MARK: - Story Section (Text left, photo right)

struct StorySection: View {
    let themePhoto: ThemePhoto
    let onPhotoTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Text on the left
            VStack(alignment: .leading, spacing: 6) {
                if let desc = themePhoto.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .lineSpacing(5)
                        .foregroundColor(.primary.opacity(0.85))
                }

                if themePhoto.photos.count > 1 {
                    Text("\(themePhoto.photos.count) photos")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Static first photo on the right, tap to see all
            if let image = themePhoto.photo.loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 150)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .onTapGesture(perform: onPhotoTap)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 120, height: 150)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Vertical Photo Viewer (full-screen, all photos stacked)

struct VerticalPhotoViewer: View {
    let photos: [PhotoInfo]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 2) {
                    ForEach(photos) { photo in
                        if let image = photo.loadImage() {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .statusBarHidden()
    }
}

// MARK: - PDF Viewer

struct PDFViewerView: View {
    let pdfData: Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitView(pdfData: pdfData)
                .navigationTitle("PDF Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: pdfData, preview: SharePreview("Month Book PDF", image: Image(systemName: "doc.richtext")))
                    }
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let pdfData: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: pdfData) {
            pdfView.document = document
        }
    }
}

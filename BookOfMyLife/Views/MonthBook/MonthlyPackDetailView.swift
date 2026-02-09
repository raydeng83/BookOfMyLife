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
    @State private var selectedPhotoIndex = 0
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

    /// Split summary into paragraphs for magazine-style layout
    private var summaryParagraphs: [String] {
        guard let summary = pack.userEditedText ?? pack.aiSummaryText else { return [] }
        return summary.components(separatedBy: "\n\n").filter { !$0.isEmpty }
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

                    if summaryParagraphs.isEmpty {
                        Text("No summary generated yet")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.horizontal)
                    } else {
                        // Magazine layout: text and photos interspersed
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
            PhotoViewerView(photos: photos, initialIndex: selectedPhotoIndex)
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

    // MARK: - Magazine Layout

    @ViewBuilder
    private var magazineContent: some View {
        let paragraphs = summaryParagraphs
        let photoQueue = distributePhotos(paragraphs: paragraphs, photos: themePhotos)

        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
            // Check if this paragraph has an associated photo
            if let photoIndex = photoQueue[index] {
                // Photo beside text layout
                MagazinePhotoTextRow(
                    text: paragraph,
                    photo: themePhotos[photoIndex].photo,
                    isPhotoLeft: index % 2 == 0,
                    onPhotoTap: {
                        selectedPhotoIndex = photoIndex
                        showingPhotoViewer = true
                    }
                )
            } else {
                // Text only
                Text(paragraph)
                    .lineSpacing(4)
                    .padding(.horizontal)
            }
        }
    }

    /// Match photos to paragraphs based on keyword matching (only matched photos shown)
    private func distributePhotos(paragraphs: [String], photos: [ThemePhoto]) -> [Int: Int] {
        var result: [Int: Int] = [:]  // paragraph index -> photo index
        var usedPhotos: Set<Int> = []

        // Only match photos to paragraphs by theme/keyword - no forced distribution
        for (pIndex, paragraph) in paragraphs.enumerated() {
            let paragraphLower = paragraph.lowercased()

            for (phIndex, themePhoto) in photos.enumerated() {
                guard !usedPhotos.contains(phIndex) else { continue }

                // Check if paragraph contains the theme or any keywords
                let themeLower = themePhoto.theme.lowercased()
                let keywordsMatch = themePhoto.dayKeywords.contains { keyword in
                    // Only match keywords with 4+ characters to avoid false positives
                    keyword.count >= 4 && paragraphLower.contains(keyword.lowercased())
                }

                if paragraphLower.contains(themeLower) || keywordsMatch {
                    result[pIndex] = phIndex
                    usedPhotos.insert(phIndex)
                    break
                }
            }
        }

        return result
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

// MARK: - Magazine Photo + Text Row (Photo embedded in text flow)

struct MagazinePhotoTextRow: View {
    let text: String
    let photo: PhotoInfo
    let isPhotoLeft: Bool
    let onPhotoTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isPhotoLeft {
                photoView
                textView
            } else {
                textView
                photoView
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var photoView: some View {
        Group {
            if let image = photo.loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .onTapGesture(perform: onPhotoTap)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 120, height: 160)
            }
        }
    }

    private var textView: some View {
        Text(text)
            .font(.body)
            .lineSpacing(5)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
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

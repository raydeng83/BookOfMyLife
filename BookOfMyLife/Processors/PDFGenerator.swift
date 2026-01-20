//
//  PDFGenerator.swift
//  BookOfMyLife
//
//  Generates two-page PDF summaries
//

import UIKit
import PDFKit

class PDFGenerator {

    // Generate monthly PDF
    func generateMonthlyPDF(pack: MonthlyPack) -> Data? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            // Page 1: Summary and statistics
            context.beginPage()
            drawMonthlyPage1(pack: pack, in: pageRect)

            // Page 2: Photos and highlights
            context.beginPage()
            drawMonthlyPage2(pack: pack, in: pageRect)
        }
    }

    // Generate yearly PDF
    func generateYearlyPDF(summary: YearlySummary) -> Data? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            // Page 1: Summary and statistics
            context.beginPage()
            drawYearlyPage1(summary: summary, in: pageRect)

            // Page 2: Photos and highlights
            context.beginPage()
            drawYearlyPage2(summary: summary, in: pageRect)
        }
    }

    // MARK: - Monthly PDF Pages

    private func drawMonthlyPage1(pack: MonthlyPack, in rect: CGRect) {
        let margin: CGFloat = 40
        var yPosition: CGFloat = margin

        // Title
        let monthName = getMonthName(Int(pack.month))
        let titleText = "\\(monthName) \\(pack.year)"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 32),
            .foregroundColor: UIColor.black
        ]
        titleText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
        yPosition += 50

        // Summary
        let summaryText = pack.userEditedText ?? pack.aiSummaryText ?? "No summary available"
        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]

        let summaryRect = CGRect(x: margin, y: yPosition, width: rect.width - 2 * margin, height: 300)
        summaryText.draw(in: summaryRect, withAttributes: summaryAttributes)
        yPosition += 320

        // Statistics
        if let statsData = pack.statsData, let stats: MonthlyStats = statsData.decoded() {
            drawMonthlyStats(stats, at: &yPosition, margin: margin, maxWidth: rect.width - 2 * margin)
        }
    }

    private func drawMonthlyPage2(pack: MonthlyPack, in rect: CGRect) {
        let margin: CGFloat = 40
        var yPosition: CGFloat = margin

        // Subtitle
        let subtitleText = "Photo Highlights"
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        subtitleText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
        yPosition += 40

        // Photos in grid
        if let photosData = pack.selectedPhotosData {
            let photos = [PhotoInfo].decoded(from: photosData)
            drawPhotoGrid(photos, startY: yPosition, in: rect, margin: margin)
        }
    }

    // MARK: - Yearly PDF Pages

    private func drawYearlyPage1(summary: YearlySummary, in rect: CGRect) {
        let margin: CGFloat = 40
        var yPosition: CGFloat = margin

        // Title
        let titleText = "\\(summary.year) in Review"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 32),
            .foregroundColor: UIColor.black
        ]
        titleText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
        yPosition += 50

        // Summary
        let summaryText = summary.userEditedText ?? summary.aiSummaryText ?? "No summary available"
        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]

        let summaryRect = CGRect(x: margin, y: yPosition, width: rect.width - 2 * margin, height: 300)
        summaryText.draw(in: summaryRect, withAttributes: summaryAttributes)
        yPosition += 320

        // Statistics
        if let statsData = summary.statsData, let stats: YearlyStats = statsData.decoded() {
            drawYearlyStats(stats, at: &yPosition, margin: margin, maxWidth: rect.width - 2 * margin)
        }
    }

    private func drawYearlyPage2(summary: YearlySummary, in rect: CGRect) {
        let margin: CGFloat = 40
        var yPosition: CGFloat = margin

        // Subtitle
        let subtitleText = "Year in Photos"
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        subtitleText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
        yPosition += 40

        // Photos in grid
        if let photosData = summary.selectedPhotosData {
            let photos = [PhotoInfo].decoded(from: photosData)
            drawPhotoGrid(photos, startY: yPosition, in: rect, margin: margin)
        }
    }

    // MARK: - Helper Drawing Methods

    private func drawMonthlyStats(_ stats: MonthlyStats, at yPosition: inout CGFloat, margin: CGFloat, maxWidth: CGFloat) {
        let statsText = """
        Statistics:
        • Days with entries: \\(stats.daysWithEntries)/\\(stats.totalDays)
        • Total photos: \\(stats.totalPhotos)
        • Total words: \\(stats.totalWords)
        • Longest streak: \\(stats.longestStreak) days
        • Starred days: \\(stats.starredDaysCount)
        """

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]

        let rect = CGRect(x: margin, y: yPosition, width: maxWidth, height: 150)
        statsText.draw(in: rect, withAttributes: attributes)
    }

    private func drawYearlyStats(_ stats: YearlyStats, at yPosition: inout CGFloat, margin: CGFloat, maxWidth: CGFloat) {
        let statsText = """
        Statistics:
        • Days with entries: \\(stats.daysWithEntries)/\\(stats.totalDays)
        • Total photos: \\(stats.totalPhotos)
        • Total words: \\(stats.totalWords)
        • Months completed: \\(stats.monthsCompleted)
        • Longest streak: \\(stats.longestStreak) days
        """

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]

        let rect = CGRect(x: margin, y: yPosition, width: maxWidth, height: 150)
        statsText.draw(in: rect, withAttributes: attributes)
    }

    private func drawPhotoGrid(_ photos: [PhotoInfo], startY: CGFloat, in pageRect: CGRect, margin: CGFloat) {
        let photosPerRow = 3
        let spacing: CGFloat = 10
        let availableWidth = pageRect.width - 2 * margin
        let photoSize = (availableWidth - CGFloat(photosPerRow - 1) * spacing) / CGFloat(photosPerRow)

        var xPosition = margin
        var yPosition = startY

        for (index, photoInfo) in photos.enumerated() {
            if let image = photoInfo.loadImage() {
                let photoRect = CGRect(x: xPosition, y: yPosition, width: photoSize, height: photoSize)
                image.draw(in: photoRect)
            }

            if (index + 1) % photosPerRow == 0 {
                xPosition = margin
                yPosition += photoSize + spacing
            } else {
                xPosition += photoSize + spacing
            }

            // Stop if we run out of space
            if yPosition + photoSize > pageRect.height - margin {
                break
            }
        }
    }

    private func getMonthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        guard let date = Calendar.current.date(from: components) else { return "" }
        return formatter.string(from: date)
    }
}

//
//  PDFGenerator.swift
//  BookOfMyLife
//
//  Generates magazine-style PDF summaries with photos interspersed in text
//

import UIKit
import PDFKit

class PDFGenerator {

    private let margin: CGFloat = 50
    private let pageWidth: CGFloat = 612  // US Letter
    private let pageHeight: CGFloat = 792

    // Generate monthly PDF with side-by-side theme photos
    func generateMonthlyPDF(pack: MonthlyPack) -> Data? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        // Get theme photos
        var themePhotos: [ThemePhoto] = []
        if let data = pack.themePhotosData {
            themePhotos = [ThemePhoto].decoded(from: data)
        }

        // Get summary paragraphs
        let summaryText = pack.userEditedText ?? pack.aiSummaryText ?? ""
        let paragraphs = summaryText.components(separatedBy: "\n\n").filter { !$0.isEmpty }

        // Get stats
        var stats: MonthlyStats?
        if let statsData = pack.statsData {
            stats = statsData.decoded()
        }

        return renderer.pdfData { context in
            drawThemePhotoLayout(
                context: context,
                pageRect: pageRect,
                title: "\(getMonthName(Int(pack.month))) \(pack.year)",
                subtitle: "Monthly Reflection",
                paragraphs: paragraphs,
                themePhotos: themePhotos,
                stats: stats
            )
        }
    }

    // Generate yearly PDF with magazine-style layout
    func generateYearlyPDF(summary: YearlySummary) -> Data? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        // Get photos
        var photos: [PhotoInfo] = []
        if let photosData = summary.selectedPhotosData {
            photos = [PhotoInfo].decoded(from: photosData)
        }

        // Get summary paragraphs
        let summaryText = summary.userEditedText ?? summary.aiSummaryText ?? ""
        let paragraphs = summaryText.components(separatedBy: "\n\n").filter { !$0.isEmpty }

        // Get stats
        var stats: YearlyStats?
        if let statsData = summary.statsData {
            stats = statsData.decoded()
        }

        return renderer.pdfData { context in
            drawMagazineLayout(
                context: context,
                pageRect: pageRect,
                title: "\(summary.year) in Review",
                subtitle: "Yearly Reflection",
                paragraphs: paragraphs,
                photos: photos,
                yearlyStats: stats
            )
        }
    }

    // MARK: - Magazine Layout

    private func drawMagazineLayout(
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        title: String,
        subtitle: String,
        paragraphs: [String],
        photos: [PhotoInfo],
        stats: MonthlyStats? = nil,
        yearlyStats: YearlyStats? = nil
    ) {
        var currentY: CGFloat = 0
        let contentWidth = pageRect.width - 2 * margin
        var photoIndex = 0
        var isFirstPage = true

        // Start first page
        context.beginPage()
        currentY = margin

        // Draw title
        currentY = drawTitle(title, at: currentY, width: contentWidth)
        currentY += 10

        // Draw subtitle
        currentY = drawSubtitle(subtitle, at: currentY, width: contentWidth)
        currentY += 20

        // Draw decorative line
        drawLine(at: currentY, width: contentWidth)
        currentY += 20

        // Interleave paragraphs and photos
        for (index, paragraph) in paragraphs.enumerated() {
            // Check if we need a new page
            let estimatedHeight = estimateTextHeight(paragraph, width: contentWidth)
            if currentY + estimatedHeight > pageRect.height - margin - 100 {
                context.beginPage()
                currentY = margin
                isFirstPage = false
            }

            // Draw paragraph
            currentY = drawParagraph(paragraph, at: currentY, width: contentWidth)
            currentY += 15

            // Insert photo row after certain paragraphs (after 1st and middle)
            let shouldInsertPhotos = (index == 0 || index == paragraphs.count / 2) && photoIndex < photos.count

            if shouldInsertPhotos {
                // Check space for photos
                let photoRowHeight: CGFloat = 150
                if currentY + photoRowHeight > pageRect.height - margin {
                    context.beginPage()
                    currentY = margin
                }

                // Draw 2-3 photos in a row
                let photosToShow = min(3, photos.count - photoIndex)
                if photosToShow > 0 {
                    currentY = drawPhotoRow(
                        Array(photos[photoIndex..<photoIndex + photosToShow]),
                        at: currentY,
                        width: contentWidth
                    )
                    photoIndex += photosToShow
                    currentY += 20
                }
            }
        }

        // Draw remaining photos if any
        while photoIndex < photos.count {
            let photoRowHeight: CGFloat = 150
            if currentY + photoRowHeight > pageRect.height - margin {
                context.beginPage()
                currentY = margin
            }

            let photosToShow = min(3, photos.count - photoIndex)
            currentY = drawPhotoRow(
                Array(photos[photoIndex..<photoIndex + photosToShow]),
                at: currentY,
                width: contentWidth
            )
            photoIndex += photosToShow
            currentY += 15
        }

        // Draw stats at the end
        if currentY + 150 > pageRect.height - margin {
            context.beginPage()
            currentY = margin
        }

        currentY += 20
        drawLine(at: currentY, width: contentWidth)
        currentY += 20

        if let stats = stats {
            drawMonthlyStatsBlock(stats, at: currentY, width: contentWidth)
        } else if let stats = yearlyStats {
            drawYearlyStatsBlock(stats, at: currentY, width: contentWidth)
        }
    }

    // MARK: - Magazine Layout with Embedded Photos

    private func drawThemePhotoLayout(
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        title: String,
        subtitle: String,
        paragraphs: [String],
        themePhotos: [ThemePhoto],
        stats: MonthlyStats? = nil
    ) {
        var currentY: CGFloat = 0
        let contentWidth = pageRect.width - 2 * margin

        // Start first page
        context.beginPage()
        currentY = margin

        // Draw title
        currentY = drawTitle(title, at: currentY, width: contentWidth)
        currentY += 10

        // Draw subtitle
        currentY = drawSubtitle(subtitle, at: currentY, width: contentWidth)
        currentY += 20

        // Draw decorative line
        drawLine(at: currentY, width: contentWidth)
        currentY += 25

        // Distribute photos to paragraphs
        let photoAssignments = distributePhotos(paragraphs: paragraphs, photos: themePhotos)

        // Draw paragraphs with embedded photos
        for (index, paragraph) in paragraphs.enumerated() {
            if let photoIndex = photoAssignments[index], photoIndex < themePhotos.count {
                // Draw paragraph with photo beside it
                let rowHeight = estimatePhotoTextRowHeight(paragraph, width: contentWidth)

                if currentY + rowHeight > pageRect.height - margin - 50 {
                    context.beginPage()
                    currentY = margin
                }

                let isPhotoLeft = index % 2 == 0
                currentY = drawPhotoTextRow(
                    themePhotos[photoIndex].photo,
                    text: paragraph,
                    at: currentY,
                    width: contentWidth,
                    isPhotoLeft: isPhotoLeft
                )
                currentY += 20
            } else {
                // Draw paragraph only
                let estimatedHeight = estimateTextHeight(paragraph, width: contentWidth)
                if currentY + estimatedHeight > pageRect.height - margin - 50 {
                    context.beginPage()
                    currentY = margin
                }
                currentY = drawParagraph(paragraph, at: currentY, width: contentWidth)
                currentY += 15
            }
        }

        // Draw stats at the end
        if currentY + 100 > pageRect.height - margin {
            context.beginPage()
            currentY = margin
        }

        currentY += 20
        drawLine(at: currentY, width: contentWidth)
        currentY += 20

        if let stats = stats {
            drawMonthlyStatsBlock(stats, at: currentY, width: contentWidth)
        }
    }

    /// Match photos to paragraphs based on keyword matching (only matched photos shown)
    private func distributePhotos(paragraphs: [String], photos: [ThemePhoto]) -> [Int: Int] {
        var result: [Int: Int] = [:]
        var usedPhotos: Set<Int> = []

        // Only match photos to paragraphs by theme/keyword - no forced distribution
        for (pIndex, paragraph) in paragraphs.enumerated() {
            let paragraphLower = paragraph.lowercased()

            for (phIndex, themePhoto) in photos.enumerated() {
                guard !usedPhotos.contains(phIndex) else { continue }

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

    private func drawPhotoTextRow(_ photo: PhotoInfo, text: String, at y: CGFloat, width: CGFloat, isPhotoLeft: Bool) -> CGFloat {
        let photoWidth: CGFloat = 120
        let photoHeight: CGFloat = 150
        let spacing: CGFloat = 15
        let textWidth = width - photoWidth - spacing

        let photoX: CGFloat
        let textX: CGFloat

        if isPhotoLeft {
            photoX = margin
            textX = margin + photoWidth + spacing
        } else {
            textX = margin
            photoX = margin + textWidth + spacing
        }

        // Draw photo
        if let image = photo.loadImage() {
            let photoRect = CGRect(x: photoX, y: y, width: photoWidth, height: photoHeight)

            UIGraphicsGetCurrentContext()?.saveGState()
            let clipPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 8)
            clipPath.addClip()
            image.draw(in: photoRect)
            UIGraphicsGetCurrentContext()?.restoreGState()

            // Light border
            UIColor.lightGray.withAlphaComponent(0.3).setStroke()
            clipPath.lineWidth = 0.5
            clipPath.stroke()
        }

        // Draw text beside photo
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.alignment = .justified

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: paragraphStyle
        ]

        let textRect = CGRect(x: textX, y: y, width: textWidth, height: photoHeight + 50)
        text.draw(in: textRect, withAttributes: textAttributes)

        return y + max(photoHeight, estimateTextHeight(text, width: textWidth)) + 10
    }

    private func estimatePhotoTextRowHeight(_ text: String, width: CGFloat) -> CGFloat {
        let photoHeight: CGFloat = 150
        let textWidth = width - 120 - 15
        let textHeight = estimateTextHeight(text, width: textWidth)
        return max(photoHeight, textHeight) + 20
    }

    // MARK: - Drawing Helpers

    private func drawTitle(_ text: String, at y: CGFloat, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: margin, y: y, width: width, height: 50)
        attributedString.draw(in: textRect)
        return y + 45
    }

    private func drawSubtitle(_ text: String, at y: CGFloat, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.gray
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: margin, y: y, width: width, height: 25)
        attributedString.draw(in: textRect)
        return y + 25
    }

    private func drawLine(at y: CGFloat, width: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: margin + width, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    private func drawParagraph(_ text: String, at y: CGFloat, width: CGFloat) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.alignment = .justified

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textHeight = estimateTextHeight(text, width: width)
        let textRect = CGRect(x: margin, y: y, width: width, height: textHeight + 10)
        attributedString.draw(in: textRect)

        return y + textHeight + 5
    }

    private func estimateTextHeight(_ text: String, width: CGFloat) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .paragraphStyle: paragraphStyle
        ]

        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        return ceil(boundingBox.height)
    }

    private func drawPhotoRow(_ photos: [PhotoInfo], at y: CGFloat, width: CGFloat) -> CGFloat {
        guard !photos.isEmpty else { return y }

        let spacing: CGFloat = 12
        let photoHeight: CGFloat = 140
        let totalSpacing = spacing * CGFloat(photos.count - 1)
        let photoWidth = (width - totalSpacing) / CGFloat(photos.count)

        var xPosition = margin

        for photoInfo in photos {
            if let image = photoInfo.loadImage() {
                // Calculate aspect-fit dimensions
                let imageAspect = image.size.width / image.size.height
                var drawWidth = photoWidth
                var drawHeight = photoHeight

                if imageAspect > photoWidth / photoHeight {
                    // Image is wider
                    drawHeight = photoWidth / imageAspect
                } else {
                    // Image is taller
                    drawWidth = photoHeight * imageAspect
                }

                let xOffset = (photoWidth - drawWidth) / 2
                let yOffset = (photoHeight - drawHeight) / 2

                let photoRect = CGRect(
                    x: xPosition + xOffset,
                    y: y + yOffset,
                    width: drawWidth,
                    height: drawHeight
                )

                // Draw rounded rect clip
                let path = UIBezierPath(roundedRect: CGRect(x: xPosition, y: y, width: photoWidth, height: photoHeight), cornerRadius: 8)
                path.addClip()
                image.draw(in: photoRect)

                // Reset clip
                UIGraphicsGetCurrentContext()?.resetClip()
            }

            xPosition += photoWidth + spacing
        }

        return y + photoHeight
    }

    private func drawMonthlyStatsBlock(_ stats: MonthlyStats, at y: CGFloat, width: CGFloat) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black
        ]

        "Statistics".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)

        let statsText = """
        Days with entries: \(stats.daysWithEntries)/\(stats.totalDays)  •  Photos: \(stats.totalPhotos)  •  Words: \(stats.totalWords)
        Longest streak: \(stats.longestStreak) days  •  Starred days: \(stats.starredDaysCount)
        """

        let statsAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.gray
        ]

        let statsRect = CGRect(x: margin, y: y + 20, width: width, height: 40)
        statsText.draw(in: statsRect, withAttributes: statsAttributes)
    }

    private func drawYearlyStatsBlock(_ stats: YearlyStats, at y: CGFloat, width: CGFloat) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black
        ]

        "Statistics".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)

        let statsText = """
        Days with entries: \(stats.daysWithEntries)/\(stats.totalDays)  •  Photos: \(stats.totalPhotos)  •  Words: \(stats.totalWords)
        Months completed: \(stats.monthsCompleted)  •  Longest streak: \(stats.longestStreak) days
        """

        let statsAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.gray
        ]

        let statsRect = CGRect(x: margin, y: y + 20, width: width, height: 40)
        statsText.draw(in: statsRect, withAttributes: statsAttributes)
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

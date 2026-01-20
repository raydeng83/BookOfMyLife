//
//  DigestProcessor.swift
//  BookOfMyLife
//
//  Processes daily digest entries with AI analysis
//

import Foundation
import CoreData
import UIKit

class DigestProcessor {
    private let visionAnalyzer = VisionAnalyzer()
    private let nlpAnalyzer = NLPAnalyzer()

    // Process a daily digest (add AI metadata if not already processed)
    func processDigest(_ digest: DailyDigest, context: NSManagedObjectContext) async {
        // Check if already processed
        if digest.lastProcessedAt != nil {
            return
        }

        var keywords: [String] = []
        var sentimentScore = 0.5

        // Process journal text with NLP
        if let text = digest.journalText, !text.isEmpty {
            let (sentiment, extractedKeywords, entities) = nlpAnalyzer.analyzeText(text)
            sentimentScore = sentiment
            keywords = extractedKeywords + entities
        }

        // Process photos with Vision
        if let photosData = digest.photosData {
            var photos = [PhotoInfo].decoded(from: photosData)

            for i in 0..<photos.count {
                if let image = photos[i].loadImage() {
                    let (scenes, hasFaces, quality, ocrText) = await visionAnalyzer.analyzePhoto(image)

                    photos[i].detectedScenes = scenes
                    photos[i].hasFaces = hasFaces
                    photos[i].qualityScore = quality
                    photos[i].ocrText = ocrText

                    // Add photo scenes to keywords
                    keywords.append(contentsOf: scenes)

                    // Add OCR text to keywords
                    if let ocrText = ocrText, !ocrText.isEmpty {
                        let (_, ocrKeywords, _) = nlpAnalyzer.analyzeText(ocrText)
                        keywords.append(contentsOf: ocrKeywords)
                    }
                }
            }

            // Save updated photo metadata
            digest.photosData = photos.encoded()
        }

        // Remove duplicates and limit to top 20 keywords
        keywords = Array(Set(keywords)).prefix(20).map { $0 }

        // Update digest
        digest.sentimentScore = sentimentScore
        digest.keywordsData = keywords.encoded()
        digest.lastProcessedAt = Date()

        // Save context
        try? context.save()
    }

    // Batch process multiple digests
    func processDigests(_ digests: [DailyDigest], context: NSManagedObjectContext) async {
        for digest in digests {
            await processDigest(digest, context: context)
        }
    }
}

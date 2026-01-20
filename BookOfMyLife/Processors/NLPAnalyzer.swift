//
//  NLPAnalyzer.swift
//  BookOfMyLife
//
//  On-device natural language processing using NaturalLanguage framework
//

import Foundation
import NaturalLanguage

class NLPAnalyzer {

    // Analyze journal text and extract insights
    func analyzeText(_ text: String) -> (sentiment: Double, keywords: [String], entities: [String]) {
        let sentimentScore = analyzeSentiment(text)
        let keywords = extractKeywords(text)
        let entities = extractEntities(text)

        return (sentimentScore, keywords, entities)
    }

    // MARK: - Sentiment Analysis

    private func analyzeSentiment(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)

        if let sentimentValue = sentiment, let score = Double(sentimentValue.rawValue) {
            // Score ranges from -1 (negative) to 1 (positive)
            // Convert to 0-1 range
            return (score + 1.0) / 2.0
        }

        return 0.5 // Neutral
    }

    // MARK: - Keyword Extraction

    private func extractKeywords(_ text: String, maxKeywords: Int = 10) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = text

        var wordFrequency: [String: Int] = [:]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                            unit: .word,
                            scheme: .lexicalClass) { tag, tokenRange in

            if let tag = tag, tag == .noun || tag == .verb || tag == .adjective {
                let word = String(text[tokenRange]).lowercased()

                // Filter out common stop words and short words
                if word.count > 3 && !isStopWord(word) {
                    wordFrequency[word, default: 0] += 1
                }
            }

            return true
        }

        // Return top keywords by frequency
        return wordFrequency
            .sorted { $0.value > $1.value }
            .prefix(maxKeywords)
            .map { $0.key }
    }

    // MARK: - Named Entity Recognition

    private func extractEntities(_ text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var entities: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                            unit: .word,
                            scheme: .nameType) { tag, tokenRange in

            if let tag = tag {
                let entity = String(text[tokenRange])

                // Extract persons, places, and organizations
                switch tag {
                case .personalName, .placeName, .organizationName:
                    entities.append(entity)
                default:
                    break
                }
            }

            return true
        }

        return Array(Set(entities)) // Remove duplicates
    }

    // MARK: - Helper Methods

    private func isStopWord(_ word: String) -> Bool {
        let stopWords = Set([
            "the", "and", "for", "are", "but", "not", "you", "all", "can",
            "her", "was", "one", "our", "out", "day", "get", "has", "him",
            "his", "how", "man", "new", "now", "old", "see", "two", "way",
            "who", "boy", "did", "its", "let", "put", "say", "she", "too",
            "use", "have", "this", "that", "with", "from", "they", "been",
            "have", "were", "said", "what", "when", "your", "into", "just",
            "know", "take", "than", "them", "well", "only", "some", "time"
        ])

        return stopWords.contains(word)
    }

    // Count words in text
    func countWords(_ text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
}

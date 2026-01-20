//
//  MonthlyPackGenerator.swift
//  BookOfMyLife
//
//  Generates monthly packs with statistics and summaries
//

import Foundation
import CoreData

class MonthlyPackGenerator {
    private let nlpAnalyzer = NLPAnalyzer()

    // Generate or update monthly pack for a given month/year
    func generateMonthlyPack(year: Int, month: Int, context: NSManagedObjectContext) async -> MonthlyPack? {
        // Fetch all digests for this month
        let digests = fetchDigestsForMonth(year: year, month: month, context: context)

        if digests.isEmpty {
            return nil
        }

        // Calculate statistics
        let stats = calculateMonthlyStats(from: digests)

        // Generate AI summary
        let summary = generateSummary(from: digests, stats: stats)

        // Create or update monthly pack
        let pack = fetchOrCreatePack(year: year, month: month, context: context)
        pack.year = Int32(year)
        pack.month = Int32(month)
        pack.statsData = stats.encoded()
        pack.aiSummaryText = summary
        pack.generatedAt = Date()

        // Select best photos for the month
        let selectedPhotos = selectBestPhotos(from: digests, maxCount: 12)
        pack.selectedPhotosData = selectedPhotos.encoded()

        try? context.save()

        return pack
    }

    // MARK: - Statistics Calculation

    private func calculateMonthlyStats(from digests: [DailyDigest]) -> MonthlyStats {
        var stats = MonthlyStats()

        // Get calendar and month info
        guard let firstDigest = digests.first,
              let firstDate = firstDigest.date else {
            return stats
        }

        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: firstDate)
        stats.totalDays = range?.count ?? 30

        // Basic counts
        stats.daysWithEntries = digests.count
        stats.starredDaysCount = digests.filter { $0.isStarred }.count

        // Photo and word counts
        for digest in digests {
            if let photosData = digest.photosData {
                let photos = [PhotoInfo].decoded(from: photosData)
                stats.totalPhotos += photos.count
            }

            if let text = digest.journalText {
                stats.totalWords += nlpAnalyzer.countWords(text)
            }
        }

        // Calculate longest streak
        stats.longestStreak = calculateLongestStreak(digests)

        // Aggregate keywords and themes
        var allKeywords: [String: Int] = [:]
        var moodCounts: [String: Int] = [:]

        for digest in digests {
            // Count moods
            if let mood = digest.userMood {
                moodCounts[mood, default: 0] += 1
            }

            // Aggregate keywords
            if let keywordsData = digest.keywordsData {
                let keywords = [String].decoded(from: keywordsData)
                for keyword in keywords {
                    allKeywords[keyword, default: 0] += 1
                }
            }
        }

        stats.topThemes = allKeywords
        stats.moodBreakdown = moodCounts

        // Extract milestone keywords (starred days)
        let starredDigests = digests.filter { $0.isStarred }
        var milestoneKeywords: Set<String> = []

        for digest in starredDigests {
            if let keywordsData = digest.keywordsData {
                let keywords = [String].decoded(from: keywordsData)
                milestoneKeywords.formUnion(keywords.prefix(3))
            }
        }

        stats.milestoneKeywords = Array(milestoneKeywords)

        return stats
    }

    private func calculateLongestStreak(_ digests: [DailyDigest]) -> Int {
        guard !digests.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedDates = digests.compactMap { $0.date }.sorted()

        var longestStreak = 1
        var currentStreak = 1

        for i in 1..<sortedDates.count {
            let previousDate = sortedDates[i - 1]
            let currentDate = sortedDates[i]

            if let daysBetween = calendar.dateComponents([.day], from: previousDate, to: currentDate).day {
                if daysBetween == 1 {
                    currentStreak += 1
                    longestStreak = max(longestStreak, currentStreak)
                } else {
                    currentStreak = 1
                }
            }
        }

        return longestStreak
    }

    // MARK: - Summary Generation

    private func generateSummary(from digests: [DailyDigest], stats: MonthlyStats) -> String {
        var summary = ""

        // Opening
        let entryRatio = Double(stats.daysWithEntries) / Double(stats.totalDays)
        if entryRatio > 0.8 {
            summary += "This was a highly documented month with entries on \(stats.daysWithEntries) out of \(stats.totalDays) days. "
        } else if entryRatio > 0.5 {
            summary += "This month had \(stats.daysWithEntries) journal entries, capturing many memorable moments. "
        } else {
            summary += "This month featured \(stats.daysWithEntries) journal entries with highlights worth remembering. "
        }

        // Mood analysis
        if let dominantMood = stats.moodBreakdown.max(by: { $0.value < $1.value }) {
            if let mood = Mood(rawValue: dominantMood.key) {
                summary += "The overall mood was predominantly \(mood.displayName.lowercased()). "
            }
        }

        // Themes
        let topThemes = stats.topThemes.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        if !topThemes.isEmpty {
            summary += "Key themes included: \(topThemes.joined(separator: ", ")). "
        }

        // Photos
        if stats.totalPhotos > 0 {
            summary += "Captured \(stats.totalPhotos) photos this month. "
        }

        // Streak
        if stats.longestStreak > 7 {
            summary += "Maintained an impressive \(stats.longestStreak)-day journaling streak. "
        }

        // Milestones
        if stats.starredDaysCount > 0 {
            summary += "\n\nStarred \(stats.starredDaysCount) special day(s) this month"
            if !stats.milestoneKeywords.isEmpty {
                summary += " featuring: \(stats.milestoneKeywords.prefix(5).joined(separator: ", "))"
            }
            summary += "."
        }

        return summary
    }

    // MARK: - Photo Selection

    private func selectBestPhotos(from digests: [DailyDigest], maxCount: Int) -> [PhotoInfo] {
        var allPhotos: [(photo: PhotoInfo, score: Double)] = []

        for digest in digests {
            if let photosData = digest.photosData {
                let photos = [PhotoInfo].decoded(from: photosData)
                for photo in photos {
                    var score = photo.qualityScore

                    // Boost score for starred days
                    if digest.isStarred {
                        score += 0.2
                    }

                    // Boost for photos with faces
                    if photo.hasFaces {
                        score += 0.1
                    }

                    allPhotos.append((photo, score))
                }
            }
        }

        // Sort by score and take top photos
        return allPhotos
            .sorted { $0.score > $1.score }
            .prefix(maxCount)
            .map { $0.photo }
    }

    // MARK: - Helper Methods

    private func fetchDigestsForMonth(year: Int, month: Int, context: NSManagedObjectContext) -> [DailyDigest] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let startDate = calendar.date(from: components),
              let endDate = calendar.date(byAdding: DateComponents(month: 1), to: startDate) else {
            return []
        }

        let fetchRequest: NSFetchRequest<DailyDigest> = DailyDigest.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DailyDigest.date, ascending: true)]

        return (try? context.fetch(fetchRequest)) ?? []
    }

    private func fetchOrCreatePack(year: Int, month: Int, context: NSManagedObjectContext) -> MonthlyPack {
        let fetchRequest: NSFetchRequest<MonthlyPack> = MonthlyPack.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "year == %d AND month == %d", year, month)

        if let existing = try? context.fetch(fetchRequest).first {
            return existing
        }

        let newPack = MonthlyPack(context: context)
        newPack.id = UUID()
        return newPack
    }
}

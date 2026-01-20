//
//  YearlySummaryGenerator.swift
//  BookOfMyLife
//
//  Generates yearly summaries from monthly packs
//

import Foundation
import CoreData

class YearlySummaryGenerator {
    private let nlpAnalyzer = NLPAnalyzer()

    // Generate or update yearly summary
    func generateYearlySummary(year: Int, context: NSManagedObjectContext) async -> YearlySummary? {
        // Fetch all monthly packs for this year
        let monthlyPacks = fetchMonthlyPacks(forYear: year, context: context)

        if monthlyPacks.isEmpty {
            return nil
        }

        // Calculate yearly statistics
        let stats = calculateYearlyStats(from: monthlyPacks)

        // Generate AI summary
        let summary = generateSummary(from: monthlyPacks, stats: stats)

        // Create or update yearly summary
        let yearlySummary = fetchOrCreateSummary(year: year, context: context)
        yearlySummary.year = Int32(year)
        yearlySummary.statsData = stats.encoded()
        yearlySummary.aiSummaryText = summary
        yearlySummary.generatedAt = Date()

        // Select best photos for the year
        let selectedPhotos = selectBestPhotos(from: monthlyPacks, maxCount: 24)
        yearlySummary.selectedPhotosData = selectedPhotos.encoded()

        try? context.save()

        return yearlySummary
    }

    // MARK: - Statistics Calculation

    private func calculateYearlyStats(from packs: [MonthlyPack]) -> YearlyStats {
        var stats = YearlyStats()

        stats.monthsCompleted = packs.count

        // Aggregate from monthly stats
        var allThemes: [String: Int] = [:]
        var allLocations: [String: Int] = [:]
        var allMoods: [String: Int] = [:]
        var allMilestones: [String] = []
        var longestStreak = 0

        for pack in packs {
            guard let statsData = pack.statsData,
                  let monthlyStats: MonthlyStats = statsData.decoded() else {
                continue
            }

            stats.daysWithEntries += monthlyStats.daysWithEntries
            stats.totalPhotos += monthlyStats.totalPhotos
            stats.totalWords += monthlyStats.totalWords
            longestStreak = max(longestStreak, monthlyStats.longestStreak)

            // Merge themes
            for (theme, count) in monthlyStats.topThemes {
                allThemes[theme, default: 0] += count
            }

            // Merge locations
            for (location, count) in monthlyStats.topLocations {
                allLocations[location, default: 0] += count
            }

            // Merge moods
            for (mood, count) in monthlyStats.moodBreakdown {
                allMoods[mood, default: 0] += count
            }

            // Collect milestone keywords
            allMilestones.append(contentsOf: monthlyStats.milestoneKeywords)
        }

        stats.topThemes = allThemes
        stats.topLocations = allLocations
        stats.moodBreakdown = allMoods
        stats.longestStreak = longestStreak

        // Extract top milestones (most frequent)
        let milestoneFrequency = Dictionary(grouping: allMilestones, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }

        stats.milestones = milestoneFrequency

        return stats
    }

    // MARK: - Summary Generation

    private func generateSummary(from packs: [MonthlyPack], stats: YearlyStats) -> String {
        var summary = ""

        // Opening
        let year = packs.first?.year ?? 0
        summary += "\(year) was documented across \(stats.monthsCompleted) months with \(stats.daysWithEntries) total journal entries. "

        // Photo count
        if stats.totalPhotos > 0 {
            summary += "This year captured \(stats.totalPhotos) photos and \(stats.totalWords) words of reflection. "
        }

        // Consistency
        let avgEntriesPerMonth = Double(stats.daysWithEntries) / Double(max(stats.monthsCompleted, 1))
        if avgEntriesPerMonth > 20 {
            summary += "Maintained exceptional consistency with an average of \(Int(avgEntriesPerMonth)) entries per month. "
        } else if avgEntriesPerMonth > 10 {
            summary += "Showed strong commitment with regular journaling throughout the year. "
        }

        // Themes
        let topThemes = stats.topThemes.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        if !topThemes.isEmpty {
            summary += "\n\nKey themes that defined the year: \(topThemes.joined(separator: ", ")). "
        }

        // Mood analysis
        if let dominantMood = stats.moodBreakdown.max(by: { $0.value < $1.value }),
           let mood = Mood(rawValue: dominantMood.key) {
            let percentage = Int((Double(dominantMood.value) / Double(stats.daysWithEntries)) * 100)
            summary += "Overall sentiment leaned \(mood.displayName.lowercased()) (\(percentage)% of entries). "
        }

        // Milestones
        if !stats.milestones.isEmpty {
            summary += "\n\nNotable milestones and moments: \(stats.milestones.prefix(5).joined(separator: ", ")). "
        }

        // Streak achievement
        if stats.longestStreak > 30 {
            summary += "\n\nAchieved an impressive \(stats.longestStreak)-day journaling streak, demonstrating remarkable dedication."
        } else if stats.longestStreak > 14 {
            summary += "\n\nMaintained a solid \(stats.longestStreak)-day journaling streak."
        }

        return summary
    }

    // MARK: - Photo Selection

    private func selectBestPhotos(from packs: [MonthlyPack], maxCount: Int) -> [PhotoInfo] {
        var allPhotos: [PhotoInfo] = []

        for pack in packs {
            if let photosData = pack.selectedPhotosData {
                let photos = [PhotoInfo].decoded(from: photosData)
                allPhotos.append(contentsOf: photos)
            }
        }

        // Take photos evenly distributed across the year
        let photosPerMonth = maxCount / max(packs.count, 1)
        var selectedPhotos: [PhotoInfo] = []

        for pack in packs {
            if let photosData = pack.selectedPhotosData {
                let photos = [PhotoInfo].decoded(from: photosData)
                selectedPhotos.append(contentsOf: photos.prefix(photosPerMonth))
            }
        }

        return Array(selectedPhotos.prefix(maxCount))
    }

    // MARK: - Helper Methods

    private func fetchMonthlyPacks(forYear year: Int, context: NSManagedObjectContext) -> [MonthlyPack] {
        let fetchRequest: NSFetchRequest<MonthlyPack> = MonthlyPack.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "year == %d", year)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MonthlyPack.month, ascending: true)]

        return (try? context.fetch(fetchRequest)) ?? []
    }

    private func fetchOrCreateSummary(year: Int, context: NSManagedObjectContext) -> YearlySummary {
        let fetchRequest: NSFetchRequest<YearlySummary> = YearlySummary.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "year == %d", year)

        if let existing = try? context.fetch(fetchRequest).first {
            return existing
        }

        let newSummary = YearlySummary(context: context)
        newSummary.id = UUID()
        return newSummary
    }
}

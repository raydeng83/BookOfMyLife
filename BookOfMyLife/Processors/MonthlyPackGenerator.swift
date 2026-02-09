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
    private let digestProcessor = DigestProcessor()

    // Generate or update monthly pack for a given month/year
    func generateMonthlyPack(year: Int, month: Int, context: NSManagedObjectContext) async -> MonthlyPack? {
        // Fetch all digests for this month
        let digests = fetchDigestsForMonth(year: year, month: month, context: context)

        if digests.isEmpty {
            return nil
        }

        // Ensure all photos are analyzed (reprocess if needed)
        print("[MonthlyPack] Reprocessing \(digests.count) digests for photo analysis...")
        for digest in digests {
            await digestProcessor.reprocessPhotos(digest, context: context)
        }

        // Re-fetch digests to get updated photo data
        let updatedDigests = fetchDigestsForMonth(year: year, month: month, context: context)

        // Calculate statistics
        let stats = calculateMonthlyStats(from: updatedDigests)

        // Extract daily entry contexts for AI
        let dailyEntries = extractDailyEntryContexts(from: updatedDigests)

        // Generate AI summary (try Foundation Models, fallback to template)
        let (summary, method) = await generateSummary(from: updatedDigests, stats: stats, month: month, year: year)

        // Extract topics using AI and select photos (try AI, fallback to keyword matching)
        let themePhotos = await selectPhotosWithAI(from: updatedDigests, dailyEntries: dailyEntries, stats: stats, maxTopics: 5)

        // Update Core Data on the context's thread
        return await context.perform {
            // Create or update monthly pack
            let pack = self.fetchOrCreatePack(year: year, month: month, context: context)
            pack.year = Int32(year)
            pack.month = Int32(month)
            pack.statsData = stats.encoded()
            pack.aiSummaryText = summary
            pack.generationMethod = method
            pack.generatedAt = Date()
            pack.themePhotosData = themePhotos.encoded()
            // Also store as selectedPhotosData for backwards compatibility
            pack.selectedPhotosData = themePhotos.map { $0.photo }.encoded()

            try? context.save()

            return pack
        }
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

    private func generateSummary(from digests: [DailyDigest], stats: MonthlyStats, month: Int, year: Int) async -> (summary: String, method: String) {
        // Try Foundation Models first (iOS 26+)
        if #available(iOS 26.0, *) {
            let service = FoundationModelsService()

            if await service.isAvailable() {
                do {
                    // Extract rich daily entry context for each day
                    let dailyEntries = extractDailyEntryContexts(from: digests)

                    // Call LLM service with rich context
                    let output = try await service.generateMonthlySummary(
                        stats: stats,
                        dailyEntries: dailyEntries,
                        month: month,
                        year: year
                    )

                    // Format structured output into final string
                    let summary = formatMonthlySummary(output)
                    print("[Monthly Pack] Generated summary using Foundation Models")
                    return (summary, "foundationModels")
                } catch {
                    // Log error, fall through to template
                    print("[Monthly Pack] LLM generation failed: \(error). Using template fallback.")
                }
            } else {
                print("[Monthly Pack] Foundation Models not available. Using template.")
            }
        }

        // Fallback: Template-based (existing code)
        let templateSummary = generateTemplateSummary(stats: stats)
        return (templateSummary, "template")
    }

    private func generateTemplateSummary(stats: MonthlyStats) -> String {
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

    // MARK: - LLM Helper Methods

    /// Extract rich context for all daily entries to pass to LLM
    private func extractDailyEntryContexts(from digests: [DailyDigest]) -> [DailyEntryContext] {
        let calendar = Calendar.current
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"  // Full weekday name

        return digests.compactMap { digest -> DailyEntryContext? in
            guard let date = digest.date else { return nil }

            let dayOfMonth = calendar.component(.day, from: date)
            let weekday = weekdayFormatter.string(from: date)

            // Extract keywords
            let keywords: [String]
            if let keywordsData = digest.keywordsData {
                keywords = [String].decoded(from: keywordsData)
            } else {
                keywords = []
            }

            // Extract photo descriptions (captions + detected scenes)
            var photoDescriptions: [String] = []
            if let photosData = digest.photosData {
                let photos = [PhotoInfo].decoded(from: photosData)
                for photo in photos {
                    if let caption = photo.caption, !caption.isEmpty {
                        photoDescriptions.append(caption)
                    } else if !photo.detectedScenes.isEmpty {
                        photoDescriptions.append(photo.detectedScenes.prefix(3).joined(separator: ", "))
                    }
                }
            }

            // Calculate word count
            let wordCount = digest.journalText.map { nlpAnalyzer.countWords($0) } ?? 0

            // Get mood display name
            let moodName = digest.userMood.flatMap { Mood(rawValue: $0)?.displayName }

            return DailyEntryContext(
                date: date,
                dayOfMonth: dayOfMonth,
                weekday: weekday,
                journalText: digest.journalText,
                mood: moodName,
                isStarred: digest.isStarred,
                keywords: keywords,
                photoDescriptions: photoDescriptions,
                wordCount: wordCount
            )
        }.sorted { $0.date < $1.date }  // Sort chronologically
    }

    /// Format structured LLM output into final summary string
    private func formatMonthlySummary(_ output: MonthlySummaryOutput) -> String {
        var parts: [String] = []

        // Opening
        parts.append(output.opening)

        // Journey narrative
        parts.append("\n\n" + output.journey)

        // Milestones
        if let milestones = output.milestones, !milestones.isEmpty {
            parts.append("\n\n" + milestones)
        }

        // Closing
        parts.append("\n\n" + output.closingReflection)

        return parts.joined(separator: "")
    }

    // MARK: - AI-Powered Photo Selection

    /// Select photos using AI-extracted topics
    private func selectPhotosWithAI(from digests: [DailyDigest], dailyEntries: [DailyEntryContext], stats: MonthlyStats, maxTopics: Int) async -> [ThemePhoto] {
        // Try AI topic extraction (iOS 26+)
        if #available(iOS 26.0, *) {
            print("[ThemePhotos] iOS 26+ detected, trying AI topic extraction...")
            let service = FoundationModelsService()

            let isAvailable = await service.isAvailable()
            print("[ThemePhotos] Foundation Models available: \(isAvailable)")

            if isAvailable {
                do {
                    print("[ThemePhotos] Extracting topics using AI with \(dailyEntries.count) entries...")
                    let topics = try await service.extractTopics(dailyEntries: dailyEntries, maxTopics: maxTopics)
                    print("[ThemePhotos] AI extracted \(topics.count) topics:")
                    for topic in topics {
                        print("[ThemePhotos]   - \(topic.name): days=\(topic.days), desc=\(topic.description)")
                    }

                    let themePhotos = selectPhotosForTopics(topics: topics, digests: digests)
                    print("[ThemePhotos] Selected \(themePhotos.count) photos for topics")
                    if !themePhotos.isEmpty {
                        return themePhotos
                    } else {
                        print("[ThemePhotos] No photos matched topics, falling back...")
                    }
                } catch {
                    print("[ThemePhotos] AI topic extraction failed: \(error). Falling back to keyword matching.")
                }
            } else {
                print("[ThemePhotos] Foundation Models not available, using fallback.")
            }
        } else {
            print("[ThemePhotos] iOS < 26, using keyword fallback.")
        }

        // Fallback to keyword-based selection
        print("[ThemePhotos] Using keyword-based fallback selection...")
        return selectThemePhotos(from: digests, stats: stats, maxThemes: maxTopics)
    }

    /// Select best photo for each AI-extracted topic
    private func selectPhotosForTopics(topics: [ExtractedTopic], digests: [DailyDigest]) -> [ThemePhoto] {
        var themePhotos: [ThemePhoto] = []
        var usedPhotoIds: Set<UUID> = []

        // Create a map of day number to digest
        let calendar = Calendar.current
        var dayToDigest: [Int: DailyDigest] = [:]
        for digest in digests {
            if let date = digest.date {
                let day = calendar.component(.day, from: date)
                dayToDigest[day] = digest
            }
        }

        for topic in topics {
            var bestMatch: (photo: PhotoInfo, score: Double)?

            // Look at digests for the days associated with this topic
            for dayNum in topic.days {
                guard let digest = dayToDigest[dayNum] else { continue }
                guard let photosData = digest.photosData else { continue }

                let photos = [PhotoInfo].decoded(from: photosData)

                for photo in photos {
                    guard !usedPhotoIds.contains(photo.id) else { continue }

                    // Score the photo
                    var score = photo.qualityScore
                    if digest.isStarred { score += 0.3 }
                    if photo.hasFaces { score += 0.2 }

                    if bestMatch == nil || score > bestMatch!.score {
                        bestMatch = (photo, score)
                    }
                }
            }

            // Add best photo for this topic
            if let match = bestMatch {
                let themePhoto = ThemePhoto(
                    theme: topic.name,
                    photo: match.photo,
                    dayKeywords: topic.days.map { "Day \($0)" },
                    description: topic.description
                )
                themePhotos.append(themePhoto)
                usedPhotoIds.insert(match.photo.id)
                print("[ThemePhotos] ✓ Topic: '\(topic.name)' | Days: \(topic.days) | Description: \(topic.description)")
            } else {
                print("[ThemePhotos] ✗ Topic: '\(topic.name)' | Days: \(topic.days) - NO PHOTO FOUND")
            }
        }

        return themePhotos
    }

    // MARK: - Keyword-Based Photo Selection (Fallback)

    /// Select one best photo for each top theme based on keywords from the day
    private func selectThemePhotos(from digests: [DailyDigest], stats: MonthlyStats, maxThemes: Int) -> [ThemePhoto] {
        // Get top themes sorted by frequency
        let topThemes = stats.topThemes
            .sorted { $0.value > $1.value }
            .prefix(maxThemes)
            .map { $0.key.lowercased() }

        print("[ThemePhotos] Top themes: \(topThemes)")

        // Count total photos available
        var totalPhotosAvailable = 0
        for digest in digests {
            if let photosData = digest.photosData {
                let photos = [PhotoInfo].decoded(from: photosData)
                totalPhotosAvailable += photos.count
            }
        }
        print("[ThemePhotos] Total photos available in digests: \(totalPhotosAvailable)")

        var themePhotos: [ThemePhoto] = []
        var usedPhotoIds: Set<UUID> = []

        // For each theme, find the best photo from a day with that keyword
        for theme in topThemes {
            var bestMatch: (photo: PhotoInfo, keywords: [String], score: Double)?

            for digest in digests {
                // Get keywords for this day
                let keywords: [String]
                if let keywordsData = digest.keywordsData {
                    keywords = [String].decoded(from: keywordsData).map { $0.lowercased() }
                } else {
                    keywords = []
                }

                // Check if this day has any keyword containing the theme (flexible matching)
                let hasTheme = keywords.contains { keyword in
                    keyword.contains(theme) || theme.contains(keyword)
                }
                guard hasTheme else { continue }

                // Get photos from this day
                guard let photosData = digest.photosData else { continue }
                let photos = [PhotoInfo].decoded(from: photosData)

                for photo in photos {
                    // Skip already used photos
                    guard !usedPhotoIds.contains(photo.id) else { continue }

                    // Calculate score
                    var score = photo.qualityScore

                    // Boost for starred days
                    if digest.isStarred {
                        score += 0.3
                    }

                    // Boost for photos with faces
                    if photo.hasFaces {
                        score += 0.15
                    }

                    // Boost if photo's detected scenes match the theme
                    if photo.detectedScenes.map({ $0.lowercased() }).contains(theme) {
                        score += 0.2
                    }

                    // Update best match
                    if bestMatch == nil || score > bestMatch!.score {
                        bestMatch = (photo, keywords, score)
                    }
                }
            }

            // Add best matching photo for this theme
            if let match = bestMatch {
                let themePhoto = ThemePhoto(
                    theme: theme.capitalized,
                    photo: match.photo,
                    dayKeywords: match.keywords.map { $0.capitalized },
                    description: nil
                )
                themePhotos.append(themePhoto)
                usedPhotoIds.insert(match.photo.id)
            }
        }

        // Fallback: If no theme photos found but photos exist, select best photos without keyword matching
        if themePhotos.isEmpty {
            var allPhotos: [(photo: PhotoInfo, digest: DailyDigest, score: Double)] = []

            for digest in digests {
                guard let photosData = digest.photosData else { continue }
                let photos = [PhotoInfo].decoded(from: photosData)

                for photo in photos {
                    var score = photo.qualityScore
                    if digest.isStarred { score += 0.3 }
                    if photo.hasFaces { score += 0.15 }
                    allPhotos.append((photo, digest, score))
                }
            }

            // Sort by score and take top photos
            let topPhotos = allPhotos.sorted { $0.score > $1.score }.prefix(maxThemes)

            let calendar = Calendar.current
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM d"

            for (index, item) in topPhotos.enumerated() {
                let keywords: [String]
                if let keywordsData = item.digest.keywordsData {
                    keywords = [String].decoded(from: keywordsData)
                } else {
                    keywords = []
                }

                // Build description from available data
                var descParts: [String] = []
                if let date = item.digest.date {
                    descParts.append("Captured on \(dateFormatter.string(from: date)).")
                }
                if !keywords.isEmpty {
                    descParts.append("Keywords: \(keywords.prefix(3).joined(separator: ", ")).")
                }
                if !item.photo.detectedScenes.isEmpty {
                    descParts.append("Scene: \(item.photo.detectedScenes.prefix(3).joined(separator: ", ")).")
                }
                let description = descParts.isEmpty ? nil : descParts.joined(separator: " ")

                let themePhoto = ThemePhoto(
                    theme: "Moment \(index + 1)",
                    photo: item.photo,
                    dayKeywords: keywords.prefix(4).map { $0.capitalized },
                    description: description
                )
                themePhotos.append(themePhoto)
                print("[ThemePhotos] Fallback: Moment \(index + 1) | Desc: \(description ?? "none")")
            }
        }

        print("[ThemePhotos] Final count: \(themePhotos.count)")
        return themePhotos
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

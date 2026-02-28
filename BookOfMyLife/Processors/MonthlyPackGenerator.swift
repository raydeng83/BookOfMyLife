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
        print("[MonthlyPack] ========== STARTING GENERATION FOR \(month)/\(year) ==========")

        // Fetch all digests for this month
        let digests = fetchDigestsForMonth(year: year, month: month, context: context)
        print("[MonthlyPack] Fetched \(digests.count) digests from Core Data")

        if digests.isEmpty {
            print("[MonthlyPack] No digests found, aborting")
            return nil
        }

        // Log each digest
        let calendar = Calendar.current
        for digest in digests {
            let day = digest.date.map { calendar.component(.day, from: $0) }
            let photoCount: Int
            if let pd = digest.photosData {
                photoCount = [PhotoInfo].decoded(from: pd).count
            } else {
                photoCount = 0
            }
            let hasText = digest.journalText != nil && !digest.journalText!.isEmpty
            let keywordCount: Int
            if let kd = digest.keywordsData {
                keywordCount = [String].decoded(from: kd).count
            } else {
                keywordCount = 0
            }
            print("[MonthlyPack]   Day \(day ?? -1): photos=\(photoCount), hasText=\(hasText), keywords=\(keywordCount), mood=\(digest.userMood ?? "nil"), starred=\(digest.isStarred)")
        }

        // Ensure all photos are analyzed (reprocess if needed)
        print("[MonthlyPack] Reprocessing \(digests.count) digests for photo analysis...")
        for digest in digests {
            await digestProcessor.reprocessPhotos(digest, context: context)
        }

        // Re-fetch digests to get updated photo data
        let updatedDigests = fetchDigestsForMonth(year: year, month: month, context: context)
        print("[MonthlyPack] Re-fetched \(updatedDigests.count) digests after reprocessing")

        // Log updated keyword state
        for digest in updatedDigests {
            let day = digest.date.map { calendar.component(.day, from: $0) }
            let keywords: [String]
            if let kd = digest.keywordsData {
                keywords = [String].decoded(from: kd)
            } else {
                keywords = []
            }
            print("[MonthlyPack]   Day \(day ?? -1) keywords after reprocess: \(keywords)")
        }

        // Calculate statistics
        let stats = calculateMonthlyStats(from: updatedDigests)
        print("[MonthlyPack] Stats: entries=\(stats.daysWithEntries)/\(stats.totalDays), photos=\(stats.totalPhotos), words=\(stats.totalWords), themes=\(stats.topThemes.count), streak=\(stats.longestStreak)")

        // Extract daily entry contexts for AI
        let dailyEntries = extractDailyEntryContexts(from: updatedDigests)
        print("[MonthlyPack] Extracted \(dailyEntries.count) daily entry contexts for AI")
        for entry in dailyEntries {
            print("[MonthlyPack]   Day \(entry.dayOfMonth) (\(entry.weekday)): mood=\(entry.mood ?? "nil"), text=\(entry.journalText?.prefix(50) ?? "nil"), keywords=\(entry.keywords.prefix(5)), photos=\(entry.photoDescriptions.count)")
        }

        // Extract narrative and photos using AI (try AI, fallback to keyword matching)
        let (themePhotos, opening, closing) = await selectPhotosWithAI(from: updatedDigests, dailyEntries: dailyEntries, stats: stats)

        // Format the narrative summary (opening + closing only, sections are in themePhotos)
        let narrativeSummary: String
        let method: String
        if let opening = opening, let closing = closing {
            narrativeSummary = "---OPENING---\n\(opening)\n---CLOSING---\n\(closing)"
            method = "foundationModels"
            print("[MonthlyPack] Using AI narrative: opening=\(opening.prefix(80))..., closing=\(closing.prefix(80))...")
        } else {
            // Fallback summary
            let (fallbackSummary, _) = await generateSummary(from: updatedDigests, stats: stats, month: month, year: year)
            narrativeSummary = fallbackSummary
            method = "template"
            print("[MonthlyPack] Using fallback summary (no AI opening/closing)")
        }

        print("[MonthlyPack] Final result: method=\(method), themePhotos=\(themePhotos.count)")
        for (i, tp) in themePhotos.enumerated() {
            print("[MonthlyPack]   Section \(i+1): theme='\(tp.theme)', desc=\(tp.description?.prefix(80) ?? "nil")")
        }
        print("[MonthlyPack] ========== GENERATION COMPLETE ==========")

        // Update Core Data on the context's thread
        return await context.perform {
            // Create or update monthly pack
            let pack = self.fetchOrCreatePack(year: year, month: month, context: context)
            pack.year = Int32(year)
            pack.month = Int32(month)
            pack.statsData = stats.encoded()
            pack.aiSummaryText = narrativeSummary
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

    /// Select photos using AI-generated per-day captions
    private func selectPhotosWithAI(from digests: [DailyDigest], dailyEntries: [DailyEntryContext], stats: MonthlyStats) async -> (photos: [ThemePhoto], opening: String?, closing: String?) {
        // Try AI caption generation (iOS 26+)
        if #available(iOS 26.0, *) {
            print("[ThemePhotos] iOS 26+ detected, trying AI caption generation...")
            let service = FoundationModelsService()

            let isAvailable = await service.isAvailable()
            print("[ThemePhotos] Foundation Models available: \(isAvailable)")

            if isAvailable {
                do {
                    let entriesWithPhotos = dailyEntries.filter { !$0.photoDescriptions.isEmpty }
                    print("[ThemePhotos] Generating captions for \(entriesWithPhotos.count) days with photos...")
                    let narrative = try await service.generateGroupedCaptions(dailyEntries: dailyEntries)
                    print("[ThemePhotos] AI generated \(narrative.sections.count) captions:")
                    for section in narrative.sections {
                        print("[ThemePhotos]   - '\(section.name)' days=\(section.days): \(section.description.prefix(60))...")
                    }

                    let themePhotos = selectPhotosForTopics(topics: narrative.sections, digests: digests)
                    print("[ThemePhotos] Matched \(themePhotos.count)/\(narrative.sections.count) captions to photos")
                    if !themePhotos.isEmpty {
                        return (themePhotos, narrative.opening, narrative.closing)
                    } else {
                        print("[ThemePhotos] No photos matched captions, falling back...")
                    }
                } catch {
                    print("[ThemePhotos] AI caption generation failed: \(error). Falling back to keyword matching.")
                }
            } else {
                print("[ThemePhotos] Foundation Models not available, using fallback.")
            }
        } else {
            print("[ThemePhotos] iOS < 26, using keyword fallback.")
        }

        // Fallback to keyword-based selection (one per day with photos)
        let daysWithPhotos = digests.filter { digest in
            if let pd = digest.photosData { return ![PhotoInfo].decoded(from: pd).isEmpty }
            return false
        }.count
        print("[ThemePhotos] Using keyword-based fallback selection (maxThemes=\(daysWithPhotos))...")
        let photos = selectThemePhotos(from: digests, stats: stats, maxThemes: daysWithPhotos)
        return (photos, nil, nil)
    }

    /// Select best photo for each AI-extracted topic (one photo per day max)
    private func selectPhotosForTopics(topics: [ExtractedTopic], digests: [DailyDigest]) -> [ThemePhoto] {
        var themePhotos: [ThemePhoto] = []
        var usedPhotoIds: Set<UUID> = []
        var usedDays: Set<Int> = []  // Track used days to avoid multiple photos from same day

        // Create a map of day number to digest
        let calendar = Calendar.current
        var dayToDigest: [Int: DailyDigest] = [:]
        for digest in digests {
            if let date = digest.date {
                let day = calendar.component(.day, from: date)
                dayToDigest[day] = digest
            }
        }

        // Log available days and their photo counts
        let availableDays = dayToDigest.keys.sorted()
        print("[PhotoMatch] Available days with digests: \(availableDays)")
        for day in availableDays {
            if let digest = dayToDigest[day], let pd = digest.photosData {
                let photos = [PhotoInfo].decoded(from: pd)
                print("[PhotoMatch]   Day \(day): \(photos.count) photo(s)")
            } else {
                print("[PhotoMatch]   Day \(day): no photos")
            }
        }

        print("[PhotoMatch] Processing \(topics.count) AI sections...")
        for (topicIndex, topic) in topics.enumerated() {
            print("[PhotoMatch] --- Section \(topicIndex + 1): '\(topic.name)' | requested days: \(topic.days) ---")
            var bestMatch: (photo: PhotoInfo, day: Int, score: Double)?

            // Look at digests for the days associated with this topic
            for dayNum in topic.days {
                // Skip days already used by other topics
                if usedDays.contains(dayNum) {
                    print("[PhotoMatch]   Day \(dayNum): SKIPPED (already used by previous section)")
                    continue
                }
                guard let digest = dayToDigest[dayNum] else {
                    print("[PhotoMatch]   Day \(dayNum): SKIPPED (no digest found for this day)")
                    continue
                }
                guard let photosData = digest.photosData else {
                    print("[PhotoMatch]   Day \(dayNum): SKIPPED (digest has no photos)")
                    continue
                }

                let photos = [PhotoInfo].decoded(from: photosData)
                print("[PhotoMatch]   Day \(dayNum): checking \(photos.count) photo(s)...")

                for photo in photos {
                    if usedPhotoIds.contains(photo.id) {
                        print("[PhotoMatch]     Photo \(photo.id.uuidString.prefix(8)): SKIPPED (already used)")
                        continue
                    }

                    // Score the photo
                    var score = photo.qualityScore
                    if digest.isStarred { score += 0.3 }
                    if photo.hasFaces { score += 0.2 }

                    print("[PhotoMatch]     Photo \(photo.id.uuidString.prefix(8)): score=\(String(format: "%.2f", score)) (quality=\(String(format: "%.2f", photo.qualityScore)), faces=\(photo.hasFaces), starred=\(digest.isStarred))")

                    if bestMatch == nil || score > bestMatch!.score {
                        bestMatch = (photo, dayNum, score)
                    }
                }
            }

            // Add best photo for this topic
            if let match = bestMatch {
                let themePhoto = ThemePhoto(
                    theme: topic.name,
                    photo: match.photo,
                    dayKeywords: [],
                    description: topic.description
                )
                themePhotos.append(themePhoto)
                usedPhotoIds.insert(match.photo.id)
                usedDays.insert(match.day)  // Mark day as used
                print("[PhotoMatch] ✓ Section \(topicIndex + 1) matched: '\(topic.name)' -> Day \(match.day), score=\(String(format: "%.2f", match.score))")
            } else {
                print("[PhotoMatch] ✗ Section \(topicIndex + 1) DROPPED: '\(topic.name)' | days \(topic.days) -> no usable photo found")
            }
        }

        print("[PhotoMatch] Result: \(themePhotos.count)/\(topics.count) sections got photos, usedDays=\(usedDays.sorted())")
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

            // Vague time references for fallback
            let timeRefs = ["One quiet morning", "On a memorable afternoon", "During a peaceful moment", "On a special occasion", "In a cherished moment"]

            for (index, item) in topPhotos.enumerated() {
                let keywords: [String] = {
                    if let keywordsData = item.digest.keywordsData {
                        return [String].decoded(from: keywordsData)
                    }
                    return []
                }()

                // Filter keywords/scenes to only meaningful, human-readable ones
                let meaningfulKeywords = keywords.filter { !Self.genericLabels.contains($0.lowercased()) }
                let meaningfulScenes = item.photo.detectedScenes
                    .filter { !Self.genericLabels.contains($0.lowercased()) }
                    .compactMap { Self.humanizeLabel($0) }

                // Build description with vague time reference
                let description: String
                let timeRef = timeRefs[index % timeRefs.count]

                if !meaningfulKeywords.isEmpty {
                    description = "\(timeRef), you captured a moment featuring \(meaningfulKeywords.prefix(2).joined(separator: " and "))."
                } else if !meaningfulScenes.isEmpty {
                    description = "\(timeRef), you captured a moment with \(meaningfulScenes.prefix(2).joined(separator: " and "))."
                } else if item.photo.hasFaces {
                    description = "\(timeRef), you captured a moment with the people around you."
                } else {
                    description = "\(timeRef), you paused to capture this memory."
                }

                // Generate title from meaningful keywords/scenes
                let title: String
                if let first = meaningfulKeywords.first {
                    title = first.capitalized
                } else if let first = meaningfulScenes.first {
                    title = first.capitalized
                } else if item.photo.hasFaces {
                    title = "Familiar Faces"
                } else {
                    title = "A Quiet Moment"
                }

                let themePhoto = ThemePhoto(
                    theme: title,
                    photo: item.photo,
                    dayKeywords: [],
                    description: description
                )
                themePhotos.append(themePhoto)
                print("[ThemePhotos] Fallback: Moment \(index + 1) | Desc: \(description)")
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

    // MARK: - Vision Label Helpers

    /// Labels that are too generic or technical to use in prose
    private static let genericLabels: Set<String> = [
        "document", "screenshot", "printed_page", "adult", "people", "person",
        "structure", "material", "object", "sign", "machine", "cord",
        "wood_processed", "circuit_board", "map"
    ]

    /// Map raw Vision identifiers to human-readable descriptions
    private static func humanizeLabel(_ label: String) -> String? {
        let mapping: [String: String] = [
            "outdoor": "the outdoors",
            "sky": "open sky",
            "blue_sky": "clear blue sky",
            "frozen": "a frozen landscape",
            "snow": "snow",
            "liquid": "water",
            "water": "water",
            "food": "food",
            "utensil": "a meal",
            "tableware": "a dining table",
            "chopsticks": "a meal",
            "plate": "a meal",
            "toy": "a toy",
            "figurine": "a figurine",
            "music": "music",
            "musical_instrument": "a musical instrument",
            "string_instrument": "a string instrument",
            "crowd": "a crowd",
            "cat": "a cat",
            "dog": "a dog",
            "plant": "greenery",
            "flower": "flowers",
            "tree": "trees",
            "mountain": "mountains",
            "beach": "the beach",
            "sunset": "a sunset",
            "sunrise": "a sunrise",
            "car": "a car",
            "bicycle": "a bicycle",
            "building": "a building",
            "book": "a book",
        ]
        return mapping[label.lowercased()] ?? label.replacingOccurrences(of: "_", with: " ")
    }
}

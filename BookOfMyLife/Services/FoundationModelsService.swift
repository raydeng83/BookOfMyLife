//
//  FoundationModelsService.swift
//  BookOfMyLife
//
//  Service for generating AI summaries using Apple's Foundation Models
//

import Foundation

// NOTE: FoundationModels framework requires iOS 26.0+
// Announced at WWDC 2025, provides access to Apple's on-device ~3B parameter LLM
// Falls back to template summaries on iOS 18-25

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Service for generating journal summaries using Apple's on-device Foundation Models
@available(iOS 26.0, *)
class FoundationModelsService {

    private let checker = AppleIntelligenceChecker()
    private let maxPromptLength = 15000 // Character limit for prompt (Foundation Models supports larger context)
    private let maxRetries = 3

    // MARK: - Public API

    /// Check if Foundation Models is available
    func isAvailable() async -> Bool {
        // Check iOS version - requires iOS 26.0+
        guard #available(iOS 26.0, *) else {
            print("[Foundation Models] Requires iOS 26.0+ (current system is older)")
            return false
        }

        // Check if framework is available at compile time
        #if canImport(FoundationModels)
        return await checker.isAvailable()
        #else
        // Framework not yet available in SDK
        print("[Foundation Models] Framework not available in current SDK (needs Xcode 26+)")
        return false
        #endif
    }

    /// Generate a monthly summary using Foundation Models
    /// - Parameters:
    ///   - stats: Monthly statistics
    ///   - dailyEntries: Rich context for each day's journal entry
    ///   - month: Month number (1-12)
    ///   - year: Year
    /// - Returns: Structured monthly summary output
    /// - Throws: FoundationModelsError if generation fails
    func generateMonthlySummary(
        stats: MonthlyStats,
        dailyEntries: [DailyEntryContext],
        month: Int,
        year: Int
    ) async throws -> MonthlySummaryOutput {
        // Build prompt with rich daily context
        let prompt = buildMonthlyPrompt(
            stats: stats,
            dailyEntries: dailyEntries,
            month: month,
            year: year
        )

        // Check prompt length
        guard prompt.count < maxPromptLength else {
            throw FoundationModelsError.promptTooLong
        }

        // Call LLM with retry logic
        let response = try await callLLMWithRetry(prompt: prompt)

        // Parse structured output
        guard let output = parseMonthlyOutput(response) else {
            throw FoundationModelsError.parsingFailed
        }

        return output
    }

    /// Generate a yearly summary using Foundation Models
    /// - Parameters:
    ///   - stats: Yearly statistics
    ///   - monthlySummaries: Summaries from each month
    ///   - year: Year
    /// - Returns: Structured yearly summary output
    /// - Throws: FoundationModelsError if generation fails
    func generateYearlySummary(
        stats: YearlyStats,
        monthlySummaries: [String],
        year: Int
    ) async throws -> YearlySummaryOutput {
        // Build prompt
        let prompt = buildYearlyPrompt(
            stats: stats,
            monthlySummaries: monthlySummaries,
            year: year
        )

        // Check prompt length
        guard prompt.count < maxPromptLength else {
            throw FoundationModelsError.promptTooLong
        }

        // Call LLM with retry logic
        let response = try await callLLMWithRetry(prompt: prompt)

        // Parse structured output
        guard let output = parseYearlyOutput(response) else {
            throw FoundationModelsError.parsingFailed
        }

        return output
    }

    // MARK: - Prompt Building

    private func buildMonthlyPrompt(
        stats: MonthlyStats,
        dailyEntries: [DailyEntryContext],
        month: Int,
        year: Int
    ) -> String {
        let monthName = getMonthName(month)

        // Extract top themes
        let topThemes = stats.topThemes
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
            .joined(separator: ", ")

        // Group entries by week
        let weeklyEntries = groupEntriesByWeek(dailyEntries, totalDays: stats.totalDays)

        // Identify starred days with their context
        let starredDays = dailyEntries.filter { $0.isStarred }
        let starredDaysText = starredDays.isEmpty ? "None" :
            starredDays.map { entry in
                var desc = "Day \(entry.dayOfMonth) (\(entry.weekday))"
                if let mood = entry.mood {
                    desc += " - \(mood)"
                }
                if !entry.keywords.isEmpty {
                    desc += ": \(entry.keywords.prefix(3).joined(separator: ", "))"
                }
                return desc
            }.joined(separator: "; ")

        // Format weekly sections
        let weeklyContent = formatWeeklyContent(weeklyEntries)

        return """
        You are a personal journaling assistant creating a monthly reflection for \(monthName) \(year).

        CRITICAL RULES:
        - NEVER make up, invent, or fabricate any events, feelings, or details
        - ONLY reference information that appears in the entries below
        - Skip over periods with no entries - do not mention them
        - Combine adjacent periods if they share similar themes or if gaps exist between them

        MONTHLY OVERVIEW:
        - Days journaled: \(stats.daysWithEntries) out of \(stats.totalDays)
        - Total photos: \(stats.totalPhotos)
        - Total words written: \(stats.totalWords)
        - Longest streak: \(stats.longestStreak) consecutive days
        - Special starred days: \(stats.starredDaysCount)
        - Top themes: \(topThemes.isEmpty ? "None identified" : topThemes)

        STARRED MOMENTS:
        \(starredDaysText)

        \(weeklyContent)

        Create a warm, personal monthly reflection as a flowing narrative. Use VAGUE time references like:
        - "The month started with...", "Early on...", "In the beginning..."
        - "As the days went by...", "Around the middle of the month...", "Things shifted when..."
        - "Later in the month...", "Toward the end...", "As the month wound down..."

        Do NOT use specific week numbers or date ranges. Let the narrative flow naturally, skipping periods without entries.

        Structure your response as follows:
        1. OPENING (1-2 sentences): Set the overall tone based on what was recorded
        2. JOURNEY (4-8 sentences): A flowing chronological narrative using vague time references. Only describe what actually happened based on the entries. Skip or combine periods with no entries.
        3. MILESTONES (1-2 sentences): Only include if starred days exist with actual content
        4. CLOSING REFLECTION (1-2 sentences): Reflect on what was actually documented

        Write in second person ("you"), speaking to your future self. Be factual and grounded in the actual entries provided.

        Respond with a JSON object:
        {
          "opening": "...",
          "journey": "...",
          "milestones": "..." or null,
          "closingReflection": "..."
        }
        """
    }

    /// Group entries into weeks (1-7, 8-14, 15-21, 22-28, 29+)
    private func groupEntriesByWeek(_ entries: [DailyEntryContext], totalDays: Int) -> [[DailyEntryContext]] {
        var weeks: [[DailyEntryContext]] = [[], [], [], [], []]

        for entry in entries {
            let day = entry.dayOfMonth
            let weekIndex: Int
            switch day {
            case 1...7: weekIndex = 0
            case 8...14: weekIndex = 1
            case 15...21: weekIndex = 2
            case 22...28: weekIndex = 3
            default: weekIndex = 4
            }
            weeks[weekIndex].append(entry)
        }

        return weeks
    }

    /// Format weekly content for the prompt
    private func formatWeeklyContent(_ weeklyEntries: [[DailyEntryContext]]) -> String {
        var sections: [String] = []

        let weekRanges = ["Days 1-7", "Days 8-14", "Days 15-21", "Days 22-28", "Days 29-31"]

        for (index, entries) in weeklyEntries.enumerated() {
            let weekNum = index + 1
            let range = weekRanges[index]

            if entries.isEmpty {
                sections.append("--- WEEK \(weekNum) (\(range)) ---\n[NO ENTRIES - Do not make up content for this week]")
                continue
            }

            // Sort entries by date within the week
            let sorted = entries.sorted { $0.date < $1.date }

            // Calculate week stats
            let moods = sorted.compactMap { $0.mood }
            let moodSummary = moods.isEmpty ? "No mood data" :
                Dictionary(grouping: moods) { $0 }
                    .mapValues { $0.count }
                    .sorted { $0.value > $1.value }
                    .prefix(2)
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: ", ")

            let starredCount = sorted.filter { $0.isStarred }.count
            let photoCount = sorted.reduce(0) { $0 + $1.photoDescriptions.count }

            var weekSection = "--- WEEK \(weekNum) (\(range)) ---\n"
            weekSection += "Entries: \(entries.count) | Moods: \(moodSummary)"
            if starredCount > 0 {
                weekSection += " | ⭐ Starred: \(starredCount)"
            }
            if photoCount > 0 {
                weekSection += " | Photos: \(photoCount)"
            }
            weekSection += "\n\n"

            // Format individual entries (limit to 4 per week to manage prompt size)
            let selectedEntries = selectBestEntries(from: sorted, maxCount: 4)
            weekSection += selectedEntries.map { $0.formatted() }.joined(separator: "\n\n")

            sections.append(weekSection)
        }

        return sections.joined(separator: "\n\n")
    }

    /// Select the most content-rich entries from a set
    private func selectBestEntries(from entries: [DailyEntryContext], maxCount: Int) -> [DailyEntryContext] {
        // Score entries by content richness
        let scored = entries.map { entry -> (DailyEntryContext, Int) in
            var score = 0
            if entry.isStarred { score += 10 }
            if entry.journalText != nil { score += 5 }
            if entry.mood != nil { score += 2 }
            score += min(entry.keywords.count, 3)
            score += min(entry.photoDescriptions.count * 2, 4)
            return (entry, score)
        }

        // Sort by score (descending), then select top entries
        let selected = scored
            .sorted { $0.1 > $1.1 }
            .prefix(maxCount)
            .map { $0.0 }

        // Re-sort by date for chronological presentation
        return selected.sorted { $0.date < $1.date }
    }

    private func buildYearlyPrompt(
        stats: YearlyStats,
        monthlySummaries: [String],
        year: Int
    ) -> String {
        // Extract top themes
        let topThemes = stats.topThemes
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
            .joined(separator: ", ")

        // Extract dominant mood
        let dominantMood = stats.moodBreakdown
            .max { $0.value < $1.value }
            .map { Mood(rawValue: $0.key)?.displayName ?? $0.key } ?? "Neutral"

        // Format monthly summaries
        let monthlyText = monthlySummaries.isEmpty ? "No monthly summaries available." :
            monthlySummaries.enumerated().map { index, summary in
                "Month \(index + 1):\n\(summary)"
            }.joined(separator: "\n\n")

        // Format milestones
        let milestonesText = stats.milestones.isEmpty ? "None" :
            stats.milestones.prefix(5).joined(separator: ", ")

        return """
        You are a personal journaling assistant creating a yearly reflection for \(year).

        YEARLY STATISTICS:
        - Total entries: \(stats.daysWithEntries) days across \(stats.monthsCompleted) months
        - Total photos: \(stats.totalPhotos)
        - Total words: \(stats.totalWords)
        - Longest streak: \(stats.longestStreak) days
        - Overall mood: \(dominantMood)
        - Top 5 themes: \(topThemes.isEmpty ? "None identified" : topThemes)

        KEY MILESTONES:
        \(milestonesText)

        MONTHLY JOURNEY:
        \(monthlyText)

        Create a comprehensive yearly reflection with these sections:

        1. YEAR OVERVIEW (2-3 sentences): The year's overarching narrative
        2. MAJOR THEMES (2-3 sentences): Identify 2-3 major themes or arcs
        3. GROWTH PATTERNS (2-3 sentences): Consistency, streaks, and evolution
        4. SIGNIFICANT MILESTONES (2-3 sentences): Celebrate key moments
        5. CHALLENGES (1-2 sentences, optional): Acknowledge difficulties if apparent
        6. FUTURE INSIGHTS (2-3 sentences): Forward-looking reflections

        Write as a letter to your future self, in second person ("you"). Identify patterns across months and celebrate growth. Keep total length to 300-400 words.

        Respond with a JSON object matching this structure:
        {
          "yearOverview": "...",
          "majorThemes": "...",
          "growthPatterns": "...",
          "significantMilestones": "...",
          "challenges": "..." or null,
          "futureInsights": "..."
        }
        """
    }

    // MARK: - LLM API Calls

    private func callLLMWithRetry(prompt: String) async throws -> String {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let response = try await callLLM(prompt: prompt)
                return response
            } catch {
                lastError = error
                print("[Foundation Models] Attempt \(attempt)/\(maxRetries) failed: \(error.localizedDescription)")

                if attempt < maxRetries {
                    // Exponential backoff
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw FoundationModelsError.generationFailed(
            lastError?.localizedDescription ?? "Max retries exceeded"
        )
    }

    private func callLLM(prompt: String) async throws -> String {
        // Check availability first
        guard await isAvailable() else {
            throw FoundationModelsError.notAvailable
        }

        #if canImport(FoundationModels)
        do {
            // Use Apple's Foundation Models API (iOS 26.0+)
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)

            return response.content
        } catch {
            // Wrap error for better handling
            throw FoundationModelsError.generationFailed(error.localizedDescription)
        }
        #else
        // Framework not available - this code path should never be reached due to isAvailable() check
        throw FoundationModelsError.notAvailable
        #endif
    }

    // MARK: - Output Parsing

    private func parseMonthlyOutput(_ jsonString: String) -> MonthlySummaryOutput? {
        // Extract JSON from response (LLM might include extra text)
        guard let jsonData = extractJSON(from: jsonString) else {
            print("[Foundation Models] Failed to extract JSON from response")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let output = try decoder.decode(MonthlySummaryOutput.self, from: jsonData)
            return output
        } catch {
            print("[Foundation Models] Failed to parse MonthlySummaryOutput: \(error)")
            return nil
        }
    }

    private func parseYearlyOutput(_ jsonString: String) -> YearlySummaryOutput? {
        // Extract JSON from response (LLM might include extra text)
        guard let jsonData = extractJSON(from: jsonString) else {
            print("[Foundation Models] Failed to extract JSON from response")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let output = try decoder.decode(YearlySummaryOutput.self, from: jsonData)
            return output
        } catch {
            print("[Foundation Models] Failed to parse YearlySummaryOutput: \(error)")
            return nil
        }
    }

    private func extractJSON(from text: String) -> Data? {
        // Try to find JSON object in response
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            let jsonString = String(text[startIndex...endIndex])
            return jsonString.data(using: .utf8)
        }

        // If entire response is JSON
        return text.data(using: .utf8)
    }

    // MARK: - Topic Extraction

    /// Extract meaningful topics from daily entries using AI
    func extractTopics(
        dailyEntries: [DailyEntryContext],
        maxTopics: Int = 5
    ) async throws -> [ExtractedTopic] {
        let prompt = buildTopicExtractionPrompt(dailyEntries: dailyEntries, maxTopics: maxTopics)

        guard prompt.count < maxPromptLength else {
            throw FoundationModelsError.promptTooLong
        }

        let response = try await callLLMWithRetry(prompt: prompt)

        guard let topics = parseTopicsOutput(response) else {
            throw FoundationModelsError.parsingFailed
        }

        return topics
    }

    private func buildTopicExtractionPrompt(dailyEntries: [DailyEntryContext], maxTopics: Int) -> String {
        // Format entries with day numbers
        let entriesText = dailyEntries.map { entry in
            var parts: [String] = ["Day \(entry.dayOfMonth):"]
            if let mood = entry.mood { parts.append("Mood: \(mood)") }
            if let text = entry.journalText, !text.isEmpty {
                let truncated = text.count > 200 ? String(text.prefix(200)) + "..." : text
                parts.append("Entry: \"\(truncated)\"")
            }
            if !entry.keywords.isEmpty {
                parts.append("Keywords: \(entry.keywords.prefix(5).joined(separator: ", "))")
            }
            if !entry.photoDescriptions.isEmpty {
                parts.append("Photos: \(entry.photoDescriptions.prefix(3).joined(separator: "; "))")
            }
            return parts.joined(separator: " | ")
        }.joined(separator: "\n")

        return """
        Analyze these journal entries and identify the \(maxTopics) most significant topics or themes.

        ENTRIES:
        \(entriesText)

        For each topic:
        1. Give it a short, meaningful name (2-4 words, e.g., "Family Gathering", "Work Project", "Beach Trip")
        2. List which days are related to this topic
        3. Write a brief description (1 sentence) that could appear in a magazine layout

        IMPORTANT:
        - Only identify topics that have actual content in the entries
        - Topics should be specific and meaningful, not generic like "daily life"
        - Each topic should relate to at least one day with photos if possible

        Respond with a JSON array:
        [
          {
            "name": "Topic Name",
            "days": [1, 5, 12],
            "description": "Brief description for magazine layout."
          }
        ]
        """
    }

    private func parseTopicsOutput(_ jsonString: String) -> [ExtractedTopic]? {
        guard let jsonData = extractJSON(from: jsonString) else {
            print("[Foundation Models] Failed to extract JSON from topics response")
            return nil
        }

        // Try parsing as array
        if let topics = try? JSONDecoder().decode([ExtractedTopic].self, from: jsonData) {
            return topics
        }

        // Try parsing as wrapper object
        if let wrapper = try? JSONDecoder().decode(TopicsWrapper.self, from: jsonData) {
            return wrapper.topics
        }

        print("[Foundation Models] Failed to parse topics")
        return nil
    }

    // MARK: - Helpers

    private func getMonthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        guard let date = Calendar.current.date(from: components) else {
            return "Month \(month)"
        }
        return formatter.string(from: date)
    }
}

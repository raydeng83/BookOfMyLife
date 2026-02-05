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
    private let maxPromptLength = 10000 // Character limit estimate for prompt
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
    ///   - sampleEntries: Sample journal text entries
    ///   - milestoneKeywords: Keywords from starred days
    ///   - month: Month number (1-12)
    ///   - year: Year
    /// - Returns: Structured monthly summary output
    /// - Throws: FoundationModelsError if generation fails
    func generateMonthlySummary(
        stats: MonthlyStats,
        sampleEntries: [String],
        milestoneKeywords: [String],
        month: Int,
        year: Int
    ) async throws -> MonthlySummaryOutput {
        // Build prompt
        let prompt = buildMonthlyPrompt(
            stats: stats,
            sampleEntries: sampleEntries,
            milestoneKeywords: milestoneKeywords,
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
        sampleEntries: [String],
        milestoneKeywords: [String],
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

        // Extract dominant mood
        let dominantMood = stats.moodBreakdown
            .max { $0.value < $1.value }
            .map { Mood(rawValue: $0.key)?.displayName ?? $0.key } ?? "Neutral"

        // Format sample entries
        let samplesText = sampleEntries.isEmpty ? "No sample text available." :
            sampleEntries.enumerated().map { index, text in
                "Entry \(index + 1):\n\(text)"
            }.joined(separator: "\n\n")

        // Format milestones
        let milestonesText = milestoneKeywords.isEmpty ? "None" :
            milestoneKeywords.joined(separator: ", ")

        return """
        You are a personal journaling assistant creating a monthly reflection for \(monthName) \(year).

        STATISTICS:
        - Days journaled: \(stats.daysWithEntries) out of \(stats.totalDays)
        - Total photos: \(stats.totalPhotos)
        - Total words: \(stats.totalWords)
        - Longest streak: \(stats.longestStreak) days
        - Starred days: \(stats.starredDaysCount)
        - Overall mood: \(dominantMood)
        - Top themes: \(topThemes.isEmpty ? "None identified" : topThemes)

        SAMPLE JOURNAL EXCERPTS:
        \(samplesText)

        SPECIAL MOMENTS:
        \(milestonesText)

        Create a warm, personal monthly reflection with these sections:

        1. OPENING (1-2 sentences): Comment on the month's documentation and overall tone
        2. MOOD ANALYSIS (2-3 sentences): Reflect on the emotional journey
        3. THEME HIGHLIGHTS (2-3 sentences): Discuss the top 2-3 themes with specific context
        4. MILESTONES (1-2 sentences, optional): Acknowledge special moments if any starred days exist
        5. CLOSING REFLECTION (1-2 sentences): Forward-looking note or insight

        Write in second person ("you"), as if speaking to your future self. Be specific and use themes/keywords from the data. Keep total length to 150-200 words.

        Respond with a JSON object matching this structure:
        {
          "opening": "...",
          "moodAnalysis": "...",
          "themeHighlights": "...",
          "milestones": "..." or null,
          "closingReflection": "..."
        }
        """
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
            // Call Foundation Models API
            // Note: The actual API usage will depend on Apple's final implementation
            // This is a placeholder based on expected API design
            let model = FoundationModel.default

            let response = try await model.generate(prompt: prompt)

            return response
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

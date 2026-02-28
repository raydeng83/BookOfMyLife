//
//  SummaryOutputTypes.swift
//  BookOfMyLife
//
//  Structured output types for Foundation Models LLM generation
//

import Foundation

/// Structured output for monthly summary generation
/// Used with @Generable for consistent LLM output formatting
struct MonthlySummaryOutput: Codable {
    /// Opening statement about the month (1-2 sentences)
    var opening: String

    /// Chronological narrative of the month with vague time references
    /// (e.g., "early on", "as the month progressed", "toward the end")
    var journey: String

    /// Special moments and milestones (optional, only if starred days exist)
    var milestones: String?

    /// Forward-looking reflection or closing thought
    var closingReflection: String
}

/// Structured output for yearly summary generation
/// Used with @Generable for consistent LLM output formatting
struct YearlySummaryOutput: Codable {
    /// Overview of the year's journey and narrative arc
    var yearOverview: String

    /// Major themes that defined the year
    var majorThemes: String

    /// Growth patterns and consistency observations
    var growthPatterns: String

    /// Significant milestones and achievements
    var significantMilestones: String

    /// Challenges faced (optional)
    var challenges: String?

    /// Insights and reflections for the future
    var futureInsights: String
}

/// AI-extracted topic from journal entries
struct ExtractedTopic: Codable {
    /// Short, meaningful topic name (e.g., "Family Gathering", "Beach Trip")
    var name: String

    /// Day numbers related to this topic
    var days: [Int]

    /// Narrative prose for magazine layout (2-3 sentences)
    var description: String
}

/// Wrapper for topics array (in case LLM wraps it)
struct TopicsWrapper: Codable {
    var topics: [ExtractedTopic]
}

/// New Yorker style narrative structure
struct MagazineNarrative: Codable {
    /// Opening prose (1-2 sentences)
    var opening: String

    /// Story sections with photos
    var sections: [ExtractedTopic]

    /// Closing reflection (1-2 sentences)
    var closing: String
}

// MARK: - Grouped Narrative (LLM groups entries by theme)

/// LLM response with entries grouped into thematic clusters
struct GroupedNarrative: Codable {
    var opening: String
    var groups: [NarrativeGroup]
    var closing: String
}

/// A thematic group containing multiple day entries
struct NarrativeGroup: Codable {
    var name: String
    var entries: [DayCaption]
}

/// A single day's caption within a group
struct DayCaption: Codable {
    var day: Int
    var caption: String
}

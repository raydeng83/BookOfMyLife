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

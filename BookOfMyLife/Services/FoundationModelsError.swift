//
//  FoundationModelsError.swift
//  BookOfMyLife
//
//  Error types for Foundation Models integration
//

import Foundation

/// Errors that can occur during Foundation Models LLM generation
enum FoundationModelsError: Error {
    /// Foundation Models framework is not available (iOS < 18 or not enabled)
    case notAvailable

    /// Device does not support Apple Intelligence (older chip)
    case deviceNotSupported

    /// Network error occurred during generation (if cloud fallback is used)
    case networkError

    /// Prompt exceeds maximum token limit
    case promptTooLong

    /// LLM generation failed with error message
    case generationFailed(String)

    /// Failed to parse structured output from LLM
    case parsingFailed

    /// User-friendly message for fallback scenarios
    var fallbackMessage: String {
        switch self {
        case .notAvailable:
            return "Using template summary (Apple Intelligence not available)"
        case .deviceNotSupported:
            return "Using template summary (device not supported)"
        case .networkError:
            return "Using template summary (network unavailable)"
        case .promptTooLong:
            return "Using template summary (content too long)"
        case .generationFailed(let message):
            return "Using template summary (generation failed: \(message))"
        case .parsingFailed:
            return "Using template summary (parsing failed)"
        }
    }

    /// Technical description for logging
    var technicalDescription: String {
        switch self {
        case .notAvailable:
            return "Foundation Models not available - iOS version < 18 or Apple Intelligence disabled"
        case .deviceNotSupported:
            return "Device chip does not support Apple Intelligence (requires A17 Pro or M-series)"
        case .networkError:
            return "Network error during LLM generation"
        case .promptTooLong:
            return "Prompt length exceeds token limit for on-device model"
        case .generationFailed(let message):
            return "LLM generation failed: \(message)"
        case .parsingFailed:
            return "Failed to parse structured output from LLM response"
        }
    }
}

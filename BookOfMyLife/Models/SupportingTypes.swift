//
//  SupportingTypes.swift
//  BookOfMyLife
//
//  Supporting types for Core Data entities (iOS 16+)
//

import Foundation
import UIKit

// MARK: - Theme Photo (photo matched to a theme/keyword)

struct ThemePhoto: Codable, Identifiable {
    var id: UUID = UUID()
    var theme: String
    var photos: [PhotoInfo]    // All photos from this day, sorted by quality
    var dayKeywords: [String]  // All keywords from the day this photo was taken
    var description: String?   // Optional description for the theme

    /// Primary (best) photo for backward compatibility
    var photo: PhotoInfo { photos.first! }

    enum CodingKeys: String, CodingKey {
        case id, theme, photos, dayKeywords, description
        // Support decoding legacy single-photo format
        case photo
    }

    init(theme: String, photos: [PhotoInfo], dayKeywords: [String], description: String?) {
        self.id = UUID()
        self.theme = theme
        self.photos = photos
        self.dayKeywords = dayKeywords
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        theme = try container.decode(String.self, forKey: .theme)
        dayKeywords = (try? container.decode([String].self, forKey: .dayKeywords)) ?? []
        description = try? container.decode(String.self, forKey: .description)
        // Try new array format first, fall back to legacy single photo
        if let arr = try? container.decode([PhotoInfo].self, forKey: .photos) {
            photos = arr
        } else if let single = try? container.decode(PhotoInfo.self, forKey: .photo) {
            photos = [single]
        } else {
            photos = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(theme, forKey: .theme)
        try container.encode(photos, forKey: .photos)
        try container.encode(dayKeywords, forKey: .dayKeywords)
        try container.encodeIfPresent(description, forKey: .description)
    }
}

// MARK: - Photo Information

struct PhotoInfo: Codable, Identifiable {
    let id: UUID
    var fileName: String
    var capturedDate: Date?

    // AI-extracted metadata (cached)
    var caption: String?
    var detectedScenes: [String]
    var hasFaces: Bool
    var qualityScore: Double
    var ocrText: String?

    var createdAt: Date

    init(fileName: String, capturedDate: Date? = nil) {
        self.id = UUID()
        self.fileName = fileName
        self.capturedDate = capturedDate
        self.detectedScenes = []
        self.hasFaces = false
        self.qualityScore = 0.5
        self.createdAt = Date()
    }

    var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photos")
            .appendingPathComponent(fileName)
    }

    func loadImage() -> UIImage? {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    func saveImage(_ image: UIImage) throws {
        let photosDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photos")

        if !FileManager.default.fileExists(atPath: photosDir.path) {
            try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        }

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw PhotoError.compressionFailed
        }

        try data.write(to: fileURL)
    }
}

enum PhotoError: Error {
    case compressionFailed
    case fileNotFound
}

// MARK: - Mood

enum Mood: String, Codable, CaseIterable {
    case great, good, neutral, challenging, difficult

    var emoji: String {
        switch self {
        case .great: return "😊"
        case .good: return "🙂"
        case .neutral: return "😐"
        case .challenging: return "😔"
        case .difficult: return "😞"
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Daily Entry Context (for LLM summaries)

/// Rich context for a single day's entry, used for generating personalized summaries
struct DailyEntryContext: Codable {
    var date: Date
    var dayOfMonth: Int
    var weekday: String
    var journalText: String?
    var mood: String?
    var isStarred: Bool
    var keywords: [String]
    var photoDescriptions: [String]  // Captions and scene descriptions
    var wordCount: Int

    /// Format entry for LLM prompt
    func formatted() -> String {
        var parts: [String] = []

        // Date header
        let starMarker = isStarred ? " ⭐" : ""
        parts.append("[\(weekday), Day \(dayOfMonth)\(starMarker)]")

        // Mood
        if let mood = mood {
            parts.append("Mood: \(mood)")
        }

        // Journal text (truncated if needed)
        if let text = journalText, !text.isEmpty {
            let truncated = text.count > 300 ? String(text.prefix(300)) + "..." : text
            parts.append("Entry: \"\(truncated)\"")
        }

        // Photo context
        if !photoDescriptions.isEmpty {
            parts.append("Photos: \(photoDescriptions.joined(separator: "; "))")
        }

        // Keywords
        if !keywords.isEmpty {
            parts.append("Keywords: \(keywords.prefix(5).joined(separator: ", "))")
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - Monthly Statistics

struct MonthlyStats: Codable {
    var totalDays: Int = 0
    var daysWithEntries: Int = 0
    var longestStreak: Int = 0
    var totalPhotos: Int = 0
    var totalWords: Int = 0

    var topThemes: [String: Int] = [:]
    var topLocations: [String: Int] = [:]
    var moodBreakdown: [String: Int] = [:]
    var milestoneKeywords: [String] = []
    var starredDaysCount: Int = 0
}

// MARK: - Yearly Statistics

struct YearlyStats: Codable {
    var totalDays: Int = 365
    var daysWithEntries: Int = 0
    var totalPhotos: Int = 0
    var totalWords: Int = 0
    var monthsCompleted: Int = 0

    var topThemes: [String: Int] = [:]
    var topLocations: [String: Int] = [:]
    var moodBreakdown: [String: Int] = [:]

    var longestStreak: Int = 0
    var milestones: [String] = []
}

// MARK: - Helper Extensions

extension Array where Element: Codable {
    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decoded(from data: Data?) -> [Element] {
        guard let data = data,
              let array = try? JSONDecoder().decode([Element].self, from: data) else {
            return []
        }
        return array
    }
}

extension Encodable {
    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

extension Data {
    func decoded<T: Decodable>() -> T? {
        try? JSONDecoder().decode(T.self, from: self)
    }
}

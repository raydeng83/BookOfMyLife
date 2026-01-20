//
//  EmptyDayView.swift
//  BookOfMyLife
//
//  Placeholder shown when no entry exists for selected day
//

import SwiftUI

struct EmptyDayView: View {
    let date: Date

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No entry for")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(dateString)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Tap + to create an entry")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

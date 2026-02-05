//
//  EmptyYearView.swift
//  BookOfMyLife
//
//  View shown when no yearly summary exists yet
//

import SwiftUI

struct EmptyYearView: View {
    let year: Int
    let onGenerate: () -> Void

    @State private var aiAvailable = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No yearly summary for")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(String(year))
                .font(.title)
                .fontWeight(.bold)

            if aiAvailable {
                Label("AI-Powered Summaries Available", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Label("Template Summaries", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: onGenerate) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Yearly Summary")
                }
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if #available(iOS 18.0, *) {
                aiAvailable = await AppleIntelligenceChecker().isAvailable()
            }
        }
    }
}

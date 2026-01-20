//
//  DailyEntryDetailView.swift
//  BookOfMyLife
//
//  Displays a saved daily journal entry
//

import SwiftUI
import CoreData

struct DailyEntryDetailView: View {
    @ObservedObject var digest: DailyDigest
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditor = false

    private var photos: [PhotoInfo] {
        guard let photosData = digest.photosData else { return [] }
        return [PhotoInfo].decoded(from: photosData)
    }

    private var keywords: [String] {
        guard let keywordsData = digest.keywordsData else { return [] }
        return [String].decoded(from: keywordsData)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    if let mood = digest.userMood, let moodEnum = Mood(rawValue: mood) {
                        Text(moodEnum.emoji)
                            .font(.largeTitle)
                        Text(moodEnum.displayName)
                            .font(.headline)
                    }

                    Spacer()

                    if digest.isStarred {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }

                    Button("Edit") {
                        showingEditor = true
                    }
                }
                .padding(.horizontal)

                if !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(photos) { photo in
                                if let image = photo.loadImage() {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 150, height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if let journalText = digest.journalText, !journalText.isEmpty {
                    Text(journalText)
                        .padding(.horizontal)
                }

                if !keywords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keywords")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(keywords, id: \.self) { keyword in
                                    Text(keyword)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.secondary.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingEditor) {
            if let date = digest.date {
                DailyEntryEditorView(date: date, existingDigest: digest)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

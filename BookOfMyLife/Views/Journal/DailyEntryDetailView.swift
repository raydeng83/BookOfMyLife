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
    @State private var showingPhotoViewer = false
    @State private var selectedPhotoIndex: Int = 0

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
                            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                                if let image = photo.loadImage() {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 150, height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .onTapGesture {
                                            selectedPhotoIndex = index
                                            showingPhotoViewer = true
                                        }
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
        .fullScreenCover(isPresented: $showingPhotoViewer) {
            PhotoViewerView(photos: photos, initialIndex: selectedPhotoIndex)
        }
    }
}

struct PhotoViewerView: View {
    let photos: [PhotoInfo]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    ZoomablePhotoView(photo: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()

                if photos.count > 1 {
                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 50)
                }
            }
        }
        .statusBarHidden()
        .onAppear {
            currentIndex = initialIndex
        }
    }
}

struct ZoomablePhotoView: View {
    let photo: PhotoInfo
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        if let image = photo.loadImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale < 1.0 {
                                withAnimation {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            } else if scale > 4.0 {
                                scale = 4.0
                                lastScale = 4.0
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                        } else {
                            scale = 2.0
                            lastScale = 2.0
                        }
                    }
                }
        }
    }
}

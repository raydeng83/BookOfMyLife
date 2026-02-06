//
//  DailyEntryEditorView.swift
//  BookOfMyLife
//
//  Editor for creating/editing daily journal entries
//

import SwiftUI
import PhotosUI
import CoreData

struct DailyEntryEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let date: Date
    var existingDigest: DailyDigest?

    @State private var journalText: String = ""
    @State private var selectedMood: Mood = .neutral
    @State private var isStarred: Bool = false
    @State private var photos: [PhotoInfo] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section("Date") {
                    Text(date, style: .date)
                }

                Section("Mood") {
                    HStack(spacing: 12) {
                        ForEach(Mood.allCases, id: \.self) { mood in
                            MoodButton(
                                mood: mood,
                                isSelected: selectedMood == mood,
                                action: { selectedMood = mood }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Photos (up to 4)") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 4 - photos.count,
                        matching: .images
                    ) {
                        Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .disabled(photos.count >= 4)

                    if !photos.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(photos) { photo in
                                    if let image = photo.loadImage() {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Button(action: { removePhoto(photo) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                            }
                                            .offset(x: 8, y: -8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Journal Entry") {
                    TextEditor(text: $journalText)
                        .frame(minHeight: 150)
                }

                Section {
                    Toggle("Star this day", isOn: $isStarred)
                }
            }
            .navigationTitle("Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(isSaving)
                }
            }
            .onChange(of: selectedPhotos) { newItems in
                Task {
                    await loadPhotos(from: newItems)
                }
            }
            .onAppear {
                loadExistingData()
            }
        }
    }

    private func loadExistingData() {
        guard let digest = existingDigest else { return }

        journalText = digest.journalText ?? ""
        isStarred = digest.isStarred

        if let moodString = digest.userMood, let mood = Mood(rawValue: moodString) {
            selectedMood = mood
        }

        if let photosData = digest.photosData {
            photos = [PhotoInfo].decoded(from: photosData)
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let fileName = "\(UUID().uuidString).jpg"
                var photoInfo = PhotoInfo(fileName: fileName)

                try? photoInfo.saveImage(image)

                await MainActor.run {
                    photos.append(photoInfo)
                }
            }
        }
    }

    private func removePhoto(_ photo: PhotoInfo) {
        photos.removeAll { $0.id == photo.id }
        try? FileManager.default.removeItem(at: photo.fileURL)
    }

    private func saveEntry() {
        isSaving = true

        let digest = existingDigest ?? DailyDigest(context: viewContext)
        digest.date = date
        digest.journalText = journalText
        digest.userMood = selectedMood.rawValue
        digest.isStarred = isStarred
        digest.photosData = photos.encoded()
        digest.createdAt = existingDigest?.createdAt ?? Date()

        if digest.id == nil {
            digest.id = UUID()
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving digest: \(error)")
            isSaving = false
        }
    }
}

struct MoodButton: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(mood.emoji)
                    .font(.system(size: 28))
                Text(mood.displayName)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

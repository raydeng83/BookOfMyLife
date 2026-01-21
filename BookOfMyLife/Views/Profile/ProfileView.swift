//
//  ProfileView.swift
//  BookOfMyLife
//
//  User profile and statistics view
//

import SwiftUI
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DailyDigest.date, ascending: false)],
        animation: .default)
    private var allDigests: FetchedResults<DailyDigest>

    private var totalEntries: Int {
        allDigests.count
    }

    private var totalPhotos: Int {
        allDigests.compactMap { digest in
            guard let photosData = digest.photosData else { return 0 }
            return [PhotoInfo].decoded(from: photosData).count
        }.reduce(0, +)
    }

    private var currentStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        var currentDate = Date()

        for _ in 0..<365 {
            let startOfDay = calendar.startOfDay(for: currentDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let hasEntry = allDigests.contains { digest in
                guard let date = digest.date else { return false }
                return date >= startOfDay && date < endOfDay
            }

            if hasEntry {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }

        return streak
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.accentColor)

                        Text("My Journal")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 32)

                    VStack(spacing: 16) {
                        ProfileStatCard(
                            icon: "book.fill",
                            label: "Total Entries",
                            value: "\(totalEntries)"
                        )

                        ProfileStatCard(
                            icon: "photo.fill",
                            label: "Total Photos",
                            value: "\(totalPhotos)"
                        )

                        ProfileStatCard(
                            icon: "flame.fill",
                            label: "Current Streak",
                            value: "\(currentStreak) days"
                        )
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.vertical)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)
                            .padding(.horizontal)

                        Text("Book of My Life helps you capture daily moments through photos and journal entries. Our on-device AI analyzes your entries to create meaningful monthly and yearly summaries.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ProfileStatCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ProfileView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

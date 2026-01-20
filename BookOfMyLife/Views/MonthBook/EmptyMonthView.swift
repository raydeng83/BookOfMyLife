//
//  EmptyMonthView.swift
//  BookOfMyLife
//
//  View shown when no monthly pack exists yet
//

import SwiftUI

struct EmptyMonthView: View {
    let year: Int
    let month: Int
    let onGenerate: () -> Void

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        guard let date = Calendar.current.date(from: components) else { return "" }
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No monthly pack for")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("\(monthName) \(year)")
                .font(.title2)
                .fontWeight(.semibold)

            Button(action: onGenerate) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Monthly Pack")
                }
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

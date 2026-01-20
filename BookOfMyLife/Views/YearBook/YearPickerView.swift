//
//  YearPickerView.swift
//  BookOfMyLife
//
//  Year selection picker
//

import SwiftUI

struct YearPickerView: View {
    @Binding var selectedYear: Int

    private let years = Array((2020...Calendar.current.component(.year, from: Date()) + 1))

    var body: some View {
        HStack {
            Button(action: previousYear) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Picker("Year", selection: $selectedYear) {
                ForEach(years, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)

            Spacer()

            Button(action: nextYear) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
    }

    private func previousYear() {
        if selectedYear > years.first ?? 2020 {
            selectedYear -= 1
        }
    }

    private func nextYear() {
        if selectedYear < years.last ?? 2030 {
            selectedYear += 1
        }
    }
}

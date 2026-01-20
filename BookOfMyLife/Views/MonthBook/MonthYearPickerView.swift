//
//  MonthYearPickerView.swift
//  BookOfMyLife
//
//  Picker for selecting month and year
//

import SwiftUI

struct MonthYearPickerView: View {
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int

    private let monthNames = Calendar.current.monthSymbols
    private let years = Array((2020...Calendar.current.component(.year, from: Date()) + 1))

    var body: some View {
        HStack {
            Picker("Month", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(monthNames[month - 1]).tag(month)
                }
            }
            .pickerStyle(.menu)

            Picker("Year", selection: $selectedYear) {
                ForEach(years, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

//
//  JournalCalendarView.swift
//  BookOfMyLife
//
//  Calendar grid showing days with entry indicators
//

import SwiftUI

struct JournalCalendarView: View {
    @Binding var selectedDate: Date
    let digestDates: Set<Date>

    private let calendar = Calendar.current
    private let weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var monthDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [Date?] = []
        var currentDate = monthFirstWeek.start

        while days.count < 42 {
            if calendar.isDate(currentDate, equalTo: selectedDate, toGranularity: .month) {
                days.append(currentDate)
            } else {
                days.append(nil)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return days
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(0..<42, id: \.self) { index in
                    if let date = monthDays[index] {
                        CalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            hasEntry: digestDates.contains(calendar.startOfDay(for: date))
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let hasEntry: Bool

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.accentColor)
            }

            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .primary)

                if hasEntry {
                    Circle()
                        .fill(isSelected ? Color.white : Color.accentColor)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(width: 4, height: 4)
                }
            }
        }
        .frame(height: 40)
    }
}

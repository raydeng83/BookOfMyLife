//
//  YearlySummaryEditorView.swift
//  BookOfMyLife
//
//  Editor for yearly summaries
//

import SwiftUI
import CoreData

struct YearlySummaryEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var summary: YearlySummary

    @State private var editedText: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section("AI Generated Summary") {
                    if let aiSummary = summary.aiSummaryText {
                        Text(aiSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No AI summary available")
                            .italic()
                    }
                }

                Section("Your Edits") {
                    TextEditor(text: $editedText)
                        .frame(minHeight: 200)
                }

                Section {
                    Button("Reset to AI Summary") {
                        editedText = summary.aiSummaryText ?? ""
                    }
                    .disabled(summary.aiSummaryText == nil)
                }
            }
            .navigationTitle("Edit Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEdits()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                editedText = summary.userEditedText ?? summary.aiSummaryText ?? ""
            }
        }
    }

    private func saveEdits() {
        isSaving = true
        summary.userEditedText = editedText

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving edits: \(error)")
            isSaving = false
        }
    }
}

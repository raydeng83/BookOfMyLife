# Book of My Life - iOS Journaling App

An iOS 16+ journaling app with on-device AI that helps you capture daily moments and generate beautiful monthly and yearly summaries.

## Features

- **Daily Journal Entries**: Add up to 4 photos and write journal notes each day
- **Mood Tracking**: Select your daily mood and star special days
- **Calendar View**: Visual calendar showing days with entries
- **On-Device AI Analysis**: Vision and NLP frameworks analyze photos and text locally
- **Monthly Summaries**: AI-generated two-page PDF summaries of each month
- **Yearly Summaries**: Comprehensive yearly reviews with statistics and highlights
- **Edit & Share**: Edit AI summaries and share PDFs

## Tech Stack

- **Minimum iOS**: 16.0
- **Data Persistence**: Core Data (iOS 16 compatible)
- **AI Processing**: Vision + NaturalLanguage frameworks (on-device)
- **Photo Storage**: File system with metadata in database
- **PDF Generation**: PDFKit

## Project Structure

```
BookOfMyLife/
├── Models/
│   └── SupportingTypes.swift          # Codable structs for complex data
├── Views/
│   ├── Journal/                       # Daily journal tab
│   │   ├── JournalView.swift
│   │   ├── CalendarHeaderView.swift
│   │   ├── JournalCalendarView.swift
│   │   ├── DailyEntryDetailView.swift
│   │   ├── DailyEntryEditorView.swift
│   │   └── EmptyDayView.swift
│   ├── MonthBook/                     # Monthly summaries tab
│   │   ├── MonthBookView.swift
│   │   ├── MonthYearPickerView.swift
│   │   ├── MonthlyPackDetailView.swift
│   │   ├── MonthlyPackEditorView.swift
│   │   └── EmptyMonthView.swift
│   ├── YearBook/                      # Yearly summaries tab
│   │   ├── YearBookView.swift
│   │   ├── YearPickerView.swift
│   │   ├── YearlySummaryDetailView.swift
│   │   ├── YearlySummaryEditorView.swift
│   │   └── EmptyYearView.swift
│   └── Profile/                       # User profile tab
│       └── ProfileView.swift
└── Processors/                        # AI and summary generation
    ├── VisionAnalyzer.swift          # Photo analysis
    ├── NLPAnalyzer.swift             # Text analysis
    ├── DigestProcessor.swift         # Daily digest processing
    ├── MonthlyPackGenerator.swift    # Monthly summary generation
    ├── YearlySummaryGenerator.swift  # Yearly summary generation
    └── PDFGenerator.swift            # PDF export
```

## Setup Instructions

### Step 1: Open Project in Xcode

1. Navigate to `/Users/ledeng/projects/ios/BookOfMyLife`
2. Open `BookOfMyLife.xcodeproj` in Xcode

### Step 2: Set Up Core Data Model

**IMPORTANT**: You must manually create the Core Data entities in Xcode's visual editor.

See detailed instructions in: `CORE_DATA_SETUP.md`

Quick summary:
1. Open `BookOfMyLife.xcdatamodeld` in Xcode
2. Add 3 entities: **DailyDigest**, **MonthlyPack**, **YearlySummary**
3. Add attributes to each entity (see CORE_DATA_SETUP.md for full list)

### Step 3: Add Files to Xcode Project

All Swift files have been created, but you need to add them to your Xcode project:

1. In Xcode, right-click on the `BookOfMyLife` folder in the Navigator
2. Select "Add Files to BookOfMyLife..."
3. Navigate to the project folder and add:
   - `Models/` folder
   - `Views/` folder (with all subfolders)
   - `Processors/` folder
4. Make sure "Copy items if needed" is **unchecked**
5. Make sure "Create groups" is selected
6. Click "Add"

### Step 4: Update Info.plist

The `Info.plist` file has already been created with photo permissions. Verify it contains:
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`

### Step 5: Build the Project

1. Select your target device (iPhone simulator or physical device)
2. Press `Cmd + B` to build
3. Fix any remaining issues (should be minimal after Core Data setup)

### Step 6: Run the App

1. Press `Cmd + R` to run
2. Grant photo permissions when prompted
3. Start journaling!

## Architecture

### Data Flow

```
Daily Entry
    ↓
DigestProcessor (Vision + NLP analysis)
    ↓
DailyDigest (cached metadata)
    ↓
MonthlyPackGenerator (aggregate statistics)
    ↓
MonthlyPack (monthly summary + PDF)
    ↓
YearlySummaryGenerator (yearly rollup)
    ↓
YearlySummary (yearly summary + PDF)
```

### Core Data Entities

**DailyDigest**
- Stores daily journal entries
- Photos stored as encoded `[PhotoInfo]` array
- Keywords and metadata cached after AI processing

**MonthlyPack**
- Aggregates data from daily digests
- Contains statistics, AI summary, selected photos
- Can be exported as 2-page PDF

**YearlySummary**
- Aggregates data from monthly packs
- Contains yearly statistics and highlights
- Can be exported as 2-page PDF

### On-Device AI

**Vision Framework**:
- Scene classification
- Face detection
- Quality assessment
- OCR text recognition

**NaturalLanguage Framework**:
- Sentiment analysis
- Keyword extraction
- Named entity recognition
- Word counting

All processing happens locally on-device with no cloud dependencies.

## Next Steps After Setup

1. **Create your first entry**: Tap the Journal tab and click the + button
2. **Generate a monthly summary**: After adding several entries, go to Month Book tab and tap "Generate Monthly Pack"
3. **View statistics**: Check the Profile tab to see your journaling stats
4. **Export PDFs**: From monthly or yearly summaries, tap "View PDF" to see the generated document

## Troubleshooting

**Build errors about missing types**:
- Ensure you've set up the Core Data model entities (see CORE_DATA_SETUP.md)
- Clean build folder: `Cmd + Shift + K`
- Rebuild: `Cmd + B`

**Photos not saving**:
- Check Info.plist has photo permissions
- Grant permissions in iOS Settings if previously denied

**App crashes on launch**:
- Check Core Data model is properly configured
- Verify all files are added to the Xcode target

## Future Enhancements

- [ ] Cloud sync via CloudKit
- [ ] Server-side LLM integration for richer summaries
- [ ] Export options (Markdown, DOCX)
- [ ] Search functionality
- [ ] Custom themes
- [ ] Apple Watch companion app
- [ ] Widget support

## License

Private project - All rights reserved

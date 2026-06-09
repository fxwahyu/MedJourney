# MedJourney — Token-Efficient AI Pipeline

This folder (`Services/AI/`) implements the curated-context AI pipeline. The core idea:
**raw journal entries and full checkup PDFs are never sent to the cloud LLM on every
call.** Instead we maintain one compact Markdown file per user — `health_summary.md` —
that is progressively updated on each save. Only that file (or a small slice of it) is
sent as context to the LLM. This achieves **~90% token reduction**.

---

## The two layers

### Layer 1 — Local extraction (no cloud, zero tokens)
| Input | Service | What it does |
|-------|---------|--------------|
| Journal free text | `LocalExtractionService` | Apple Foundation Models → symptom tags; vital-alert tags derived locally from thresholds |
| Checkup image/PDF | `CheckupOCRService` | Apple Vision (`VNRecognizeTextRequest`) → clean plain text |

### Layer 2 — Cloud LLM (targeted calls only)
| Trigger | Service method | Context sent |
|---------|----------------|--------------|
| Checkup uploaded | `LLMAnalysisService.analyzeCheckup(extractedText:)` | OCR text, **once** |
| Health Insights | `LLMAnalysisService.generateHealthInsights(summary:timeRange:)` | the MD file |
| Daily greeting | `LLMAnalysisService.generateDailyGreeting(summaryContext:)` | only the *Daily Summary Context* slice |
| Journal tags (fallback) | `LLMAnalysisService.generateDailyTags(journalText:)` | journal text — **only when on-device model is unavailable** |

> The MD file is the curated context layer. It is an *additional* layer — the raw
> entries and uploaded files remain in the existing SwiftData / persistence layer. The
> pipeline never replaces or duplicates that storage.

---

## Flow diagrams

**Journal save** (`JournalEntryPipeline.process(entry:)`)
```
entry ─▶ LocalExtractionService.extractTags (on-device)
            │  (if on-device unavailable AND no symptom tags)
            └─▶ LLMAnalysisService.generateDailyTags (cloud fallback)
      ─▶ HealthSummaryManager.updateFromJournalEntry   (append, cap 30)
      ─▶ [background] HealthSummaryManager.updateDailySummaryContext
      ─▶ ProcessedJournalResult { tags, usedCloudFallback, tokenEstimate }
```

**Checkup upload** (`CheckupUploadPipeline.process(fileData:fileType:)`)
```
fileData ─▶ CheckupOCRService.extractText (on-device OCR)
         ─▶ LLMAnalysisService.analyzeCheckup (ONE cloud call)
         ─▶ HealthSummaryManager.updateFromCheckupAnalysis (output only)
         ─▶ HealthSummaryManager.updateDailySummaryContext
         ─▶ CheckupAnalysis (returned to UI)
```

---

## `health_summary.md`

Owned exclusively by `HealthSummaryManager` (a Swift `actor` → all file I/O is
serialized and thread-safe). Stored at `<Documents>/health_summary.md`. Sections follow
the documented schema (Active Conditions, Lab Trends, Recent Journal Tags, Medications,
Doctor Notes & Follow-ups, Flagged Abnormals, Daily Summary Context).

- **Recent Journal Tags** is capped at the last **30** entries to prevent unbounded growth.
- `getSummaryTokenEstimate()` gives a rough `chars / 4` token estimate to confirm the
  file is staying within budget.
- `getDailySummaryContext()` returns **only** the small *Daily Summary Context* section —
  this is what the greeting generator consumes.

---

## Daily greeting cache logic (`DailySummaryService`)

The home-screen greeting is expensive (a cloud call), so it is cached for the day:

`shouldRegenerateToday()` returns `true` when **any** of these hold:
1. There is no cached greeting yet.
2. The cached greeting was generated **before today** (calendar rollover / past midnight).
3. The `health_summary.md` file was **modified since** the cached greeting was generated
   (a new journal entry or checkup landed → context is stale).

Otherwise the cached `DailyGreeting` is returned with `isFromCache = true`. The cache
lives in `UserDefaults`. Wire it up from the Home view's `onAppear` / `.task`.

Tone escalates with the user's condition:
- `.normal` — "Good morning! Your vitals have been stable this week."
- `.alert` — soft mention of a mild recent flag.
- `.critical` — "You had a high fever yesterday — how are you feeling now?"

---

## Wiring up the API key

Keys are **never hardcoded**. `AIConfig.llmAPIKey` resolves in this order (first non-empty wins):

1. **`Config.plist`** → key `GEMINI_API_KEY`
2. **Environment variable** `GEMINI_API_KEY` (Xcode scheme → Edit Scheme → Run → Arguments → Environment Variables)
3. The app's existing `APIKeys.gemini` (back-compat fallback)

### Create `Config.plist` (recommended)
1. In Xcode: **File → New → File → Property List**, name it `Config.plist`, add it to the `MedJourney` target.
2. Add a String row:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GEMINI_API_KEY</key>
    <string>your-real-key-here</string>
</dict>
</plist>
```

3. `Config.plist` is already added to `.gitignore` — **do not commit it**.

### Testing without the network
`LLMAnalysisService(dryRun: true)` returns deterministic mock responses for every method
— no API key required. Use it in previews, unit tests, and offline development.

---

## Files in this folder

| File | Role |
|------|------|
| `HealthSummaryManager.swift` | Actor that reads/writes `health_summary.md` |
| `LocalExtractionService.swift` | On-device tag extraction (delegates to existing `FoundationModelsService`) |
| `CheckupOCRService.swift` | Vision OCR for image + PDF |
| `LLMAnalysisService.swift` | Single funnel for all cloud LLM calls (+ `dryRun` mocks) |
| `JournalEntryPipeline.swift` | Orchestrates journal-save flow |
| `CheckupUploadPipeline.swift` | Orchestrates checkup-upload flow |
| `DailySummaryService.swift` | Home greeting + day-cache |
| `AIConfig.swift` | Resolves the API key (Config.plist → env → APIKeys) |

Supporting models live in `Models/AI/`: `HealthTag`, `LabMarker`, `CheckupAnalysis`,
`HealthInsights`, `InsightTimeRange`, `DailyGreeting`.

---

## ⚠️ Existing fallback logic is preserved

The on-device availability + fallback rules already in `FoundationModelsService` are **not
modified**. `LocalExtractionService` *delegates* to `FoundationModelsService.shared`
(reusing its `isAvailable`, the `GenerationError -1` skip-caching, and iOS gating) rather
than re-implementing any of it. Cloud fallbacks run **only** when that existing service
reports the on-device model unavailable. Look for `// NOTE: preserving existing fallback
logic` comments at each integration point.

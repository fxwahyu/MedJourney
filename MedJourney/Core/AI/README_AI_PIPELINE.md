# MedJourney — AI Pipeline (`Core/AI/`)

The core idea: **raw journal entries and checkup documents are never re-sent to
the cloud LLM.** A compact per-user Markdown file — `health_summary.md` — is
progressively updated on each save, and only that file (or a small slice of it)
is sent as LLM context.

## Layers

**Transport — `LLMGateway`**
The single gate for every cloud LLM call. Picks the first configured provider
(Groq → Gemini), falls through on rate limits, retries once on HTTP 429. To
change provider, model, or fallback order, edit only this file. Keys resolve
via `AIConfig` (Config.plist → environment variable; never hardcoded).

**On-device — `FoundationModelsService`** (Apple Foundation Models, iOS 26+)
- Journal pre-processing: urgency detection + noise stripping before any cloud call
- Home daily briefing (preferred path)
- Insight phrasing for locally computed stats

`VitalsAnomalyDetector` (pure Swift, no ML) and `DocumentScannerService`
(Vision OCR) are also fully on-device.

**Cloud services** (all route through `LLMGateway`)
| Service | Responsibility | Context sent |
|---|---|---|
| `LLMTagService` | Journal tags + checkup analysis | cleaned text / OCR text, once |
| `ChecklistGenerationService` | Daily habit checklist; tag-insight phrasing fallback | OCR text + notes |
| `LLMAnalysisService` | Insights deep summary; daily greeting fallback | curated MD file / context slice |

**Curated context — `HealthSummaryManager`**
Actor that owns `<Documents>/health_summary.md`. Journal saves and checkup
analyses append compact lines (capped at 30 journal / 20 checkup rows).
`getDailySummaryContext()` returns only the small slice the greeting consumes.

**Caching — `DailySummaryService` / `HomeViewModel`**
The daily greeting/briefing is cached and only regenerated when the calendar
day rolls over or `health_summary.md` was modified since the last generation.

## API keys

Create a `Config.plist` in the `MedJourney` target (git-ignored, do not commit):

```xml
<dict>
    <key>GEMINI_API_KEY</key>
    <string>your-key</string>
    <key>GROQ_API_KEY</key>
    <string>your-key</string>
</dict>
```

Environment variables of the same names (Xcode scheme → Run → Environment
Variables) work as a fallback.

## Testing without the network

`LLMAnalysisService(dryRun: true)` returns deterministic mock responses for
every method — no API key required. Use it in previews and unit tests.

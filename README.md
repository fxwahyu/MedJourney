# MedJourney

> *My mom visits the doctor every few weeks. Every time, the doctor asks "how have you been feeling?" — and every time, she can't quite remember. Was the fatigue worse on Tuesday or Thursday? Did the headache start before or after the new medication? She'd look at me, I'd shrug. We were both guessing.*
>
> *That's why I built this.*

<br>

MedJourney is a personal health journaling iOS app that lets you upload and track your medical checkup results over time, then uses AI to explain what those results actually mean — in plain language, not medical jargon. The goal isn't to replace your doctor. It's to make sure you walk into that appointment with something real to say.

<br>

## What it does

You snap a photo or upload a PDF of your medical result. The app reads it on-device, breaks down each value, flags anything outside the normal range, and gives you a plain-language summary — along with a list of questions worth bringing up with your doctor and a daily habit checklist built from the findings.

Day to day, you log how you feel: mood, free-text journal, optional vitals. The app tags your symptoms with AI, detects when a vital drifts from *your* personal baseline, and turns it all into trends, streaks, and a daily briefing.

No social feed. No guilt-trip gamification. Your health data, explained clearly, stored privately on your device.

<br>

## Screenshots

> *Coming soon — currently in active development.*

<br>

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| UI | SwiftUI | Declarative, composable, feels native |
| Architecture | MVVM (`@Observable` ViewModels) | Clean separation, easy to test |
| Local storage | SwiftData | First-class Swift persistence, no CoreData boilerplate |
| On-device AI | Apple Foundation Models (iOS 26+) | Private urgency detection, briefing & insight phrasing — zero tokens |
| Cloud AI | Groq (Llama 3.3) → Gemini fallback via a single `LLMGateway` | One transport, swappable providers |
| OCR | Apple Vision | Documents never leave the device for text extraction |
| Charts | Swift Charts | Mood, vitals, and symptom-frequency trends |
| Reminders | UserNotifications | Medicine schedules with Taken/Skip actions |

No third-party dependencies. No SPM packages. Just the platform.

<br>

## Project structure

```
MedJourney/
├── App/                              # Entry point, root tab view, global add sheet
├── Core/
│   ├── AI/                           # The whole AI pipeline (see Core/AI/README_AI_PIPELINE.md)
│   │   ├── LLMGateway.swift          # Single gate for every cloud LLM call (Groq → Gemini)
│   │   ├── FoundationModelsService.swift  # On-device AI: urgency check, briefing, phrasing
│   │   ├── LLMTagService.swift       # Symptom tags + checkup analysis prompts
│   │   ├── ChecklistGenerationService.swift
│   │   ├── LLMAnalysisService.swift  # Deep insights + daily greeting (curated context only)
│   │   ├── HealthSummaryManager.swift # Curated health_summary.md — the token-saving layer
│   │   ├── VitalsAnomalyDetector.swift # Personal-baseline anomaly detection, pure Swift
│   │   └── Models/                   # HealthTag, HealthInsights, DailyGreeting, …
│   ├── Components/                   # Reusable UI: buttons, cards, fields, AI components
│   ├── DesignSystem/                 # Vital Calm tokens: colors, typography, spacing, shadows
│   └── Persistence/                  # SwiftData container, models, seed data
└── Features/                         # One folder per feature, each with Views + ViewModels
    ├── Home/                         # Daily briefing, checklist, medicine schedule
    ├── Journal/                      # Mood journal, checkup upload, entry detail
    ├── Medicine/                     # Medicine tracker + reminders
    ├── Insights/                     # Charts, streaks, AI summary, PDF export
    └── Onboarding/
```

<br>

## How the AI works

Two layers, deliberately separated:

1. **On-device first** (Apple Foundation Models + Vision + pure Swift): OCR, red-flag urgency detection before anything is saved, journal noise-stripping, vitals anomaly detection against your own baseline, and phrasing of locally computed stats. All free, private, offline.

2. **Cloud, but curated**: instead of re-sending raw entries on every call, each save appends a compact line to a per-user `health_summary.md`. Deep insights and daily greetings are generated from that file (or a small slice of it) — roughly 90% fewer tokens than shipping raw history. Every cloud call goes through one `LLMGateway`, so swapping providers is a one-file change.

Every AI response is observational by design — the prompts forbid diagnosis and frame abnormal values as "worth discussing with your doctor."

<br>

## Running the project

```bash
git clone https://github.com/fxwahyu/MedJourney.git
cd MedJourney
open MedJourney.xcodeproj
```

Create a `Config.plist` in the `MedJourney` target (git-ignored) with your keys:

```xml
<key>GEMINI_API_KEY</key>
<string>your-key-here</string>
<key>GROQ_API_KEY</key>
<string>your-key-here</string>
```

Requires Xcode 16+ and iOS 26+ (Foundation Models minimum deployment target). Without Apple Intelligence the app falls back to cloud generation; without any API key the AI surfaces degrade gracefully.

<br>

## Why this and not just Notes.app

Notes doesn't know what a creatinine level means. MedJourney does.

More practically: the problem isn't that people don't write things down. It's that what they write down isn't structured or interpreted in a way that's useful at a doctor's appointment. A photo of a lab result sitting in your camera roll doesn't help anyone. A structured summary of what that result means, with the right questions attached, does.

<br>

---

<sub>MedJourney is not a medical device and does not provide medical advice. All AI-generated content is for informational purposes only. Always consult a qualified healthcare professional for medical decisions.</sub>

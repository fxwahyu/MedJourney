<div align="center">

<img width="120" height="120" alt="appstore" src="https://github.com/user-attachments/assets/39f84811-ad39-40e5-bee7-9beef74fcb47" />

# MedJourney

**AI-powered health journal for iOS — built with a token-efficient, two-layer LLM pipeline**

[![Swift](https://img.shields.io/badge/Swift-6.0-FA7343?style=flat&logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17+-000000?style=flat&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-1C6EF2?style=flat&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![LLM APIs](https://img.shields.io/badge/Claude-API-8B5CF6?style=flat&logo=anthropic&logoColor=white)](https://anthropic.com)
[![Apple Intelligence](https://img.shields.io/badge/Apple_Intelligence-Foundation_Models-black?style=flat&logo=apple&logoColor=white)](https://developer.apple.com/apple-intelligence/)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat)](LICENSE)
[![Status](https://img.shields.io/badge/status-active_development-brightgreen?style=flat)]()

<br/>

> *"Most health apps store data. MedJourney understands it."*

[Features](#-features) · [Architecture](#-ai-pipeline-architecture) · [Token Efficiency](#-token-efficiency-design) · [Tech Stack](#-tech-stack) · [Getting Started](#-getting-started) · [Roadmap](#-roadmap)

</div>

---

## 🩺 What is MedJourney?

MedJourney is an **indie iOS health tracker** that lets users log daily health journals, upload medical checkup documents, and receive AI-driven health insights — all with a calm, privacy-first experience.

The core engineering challenge wasn't building the UI. It was designing an **AI pipeline that actually scales** — one that doesn't blow your LLM budget with every tap, doesn't hallucinate context from 6 weeks ago, and works even when the user is offline.

That required rethinking how LLM context is built, curated, and served.

---

## ✨ Features

- **📓 Daily Health Journal** — structured symptom logging with mood, energy, pain, and custom tags
- **📄 Medical Document OCR** — upload lab results or prescriptions; Vision extracts the data
- **🤖 AI Health Insights** — personalized summaries and pattern analysis powered by Claude API
- **📊 Health Timeline** — visual history of entries with trend indicators
- **🌤 Daily Greeting Card** — context-aware morning card generated from your rolling health summary
- **📴 Offline-first** — Apple Foundation Models handle on-device inference when network is unavailable
- **🔒 Privacy by design** — health data stays local; cloud LLM only receives a curated, anonymizable summary
- **🩺 Doctor-ready report** — your journal history, medical checkups, and medication can be exported into a PDF you can bring to your next appointment

---

## 🧠 AI Pipeline Architecture

This is the part that took the most architectural thought.

Most LLM-integrated apps make one of two mistakes: they either send **raw, full chat history** to the cloud (expensive, slow, context-polluted), or they go **fully on-device** and sacrifice quality. MedJourney uses a **two-layer hybrid pipeline** that avoids both traps.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         MEDJOURNEY AI PIPELINE                          │
└─────────────────────────────────────────────────────────────────────────┘

  USER ACTION                 LAYER 1 (On-Device)          LAYER 2 (Cloud LLM)
  ─────────────              ──────────────────────        ─────────────────────
                              Apple Foundation Models       Claude API
  Journal Save ──────────►   Swift 6 Structured Output ─►  health_summary.md
  Checkup Upload ────────►   Vision OCR + Extraction   ─►  (sole context source)
  Greeting Card Request ─►   Direct MD read (no LLM)        Deep pattern analysis
                              ↓
                         health_summary.md (updated)
                              ↓
                        ~400–600 tokens of curated context
                        (vs. 4,000–8,000 raw history tokens)
```

### Layer 1 — On-Device Extraction
Apple Foundation Models (`FoundationModels.framework`, iOS 18+) handle:
- Structuring free-text journal entries into typed fields
- Running Vision OCR on uploaded medical documents
- Parsing and normalizing extracted lab values into structured Markdown

> No cloud call happens at this stage. Zero tokens spent.

### Layer 2 — Cloud LLM Analysis
Claude API receives **only** `health_summary.md` — a curated, rolling Markdown file that is maintained per-user and updated after every journal save or document upload.

This file is the **only context the cloud LLM ever sees**. It is not a dump of raw entries; it is a distilled, structured summary that the on-device layer keeps current.

---

## ⚡ Token Efficiency Design

> **Result: ~90% reduction in tokens per cloud LLM request** compared to naive full-history approaches.

The `health_summary.md` strategy was the key architectural decision. Here's the thinking:

### The Problem with Naive Approaches

| Approach | Tokens/Request | Cost at Scale | Staleness Risk |
|---|---|---|---|
| Full chat history | 4,000–8,000 | 💸 Very high | Low |
| Last N entries | 1,500–3,000 | 💸 High | Medium |
| **health_summary.md (MedJourney)** | **400–600** | **✅ Low** | **None — always current** |

### How `health_summary.md` Works

```markdown
# Health Summary — [User]
Last updated: 2025-06-10T08:22:00

## Vitals Snapshot
- Blood pressure: 120/80 (last checked: 2025-05-28)
- Weight trend: stable (±0.5 kg over 30 days)

## Active Symptoms
- Mild fatigue (logged 4x in last 14 days)
- Occasional lower back discomfort (new, flagged 2025-06-08)

## Medications
- Vitamin D 1000 IU (daily, ongoing)

## Recent Checkups
- Full blood panel 2025-05-28: all values in normal range except slightly low Ferritin (18 ng/mL)

## Patterns Detected
- Energy dips correlate with poor sleep quality entries (Pearson r ≈ 0.71)

## AI Notes
- Suggest monitoring iron levels on next checkup
- No acute symptoms warranting escalation
```

This file is **rewritten, not appended**, on every save. The cloud LLM never needs to infer history from raw entries — it reads a curated, always-accurate snapshot.

The daily greeting card reads directly from this file via the on-device layer — **zero cloud tokens** for that feature.

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 (strict concurrency) |
| UI Framework | SwiftUI 5 |
| On-Device AI | Apple Foundation Models (FoundationModels.framework) |
| OCR | VisionKit / Vision framework |
| Cloud LLM | Groq, Gemini, Anthropic (soon) |
| Markdown Rendering | swift-markdown-ui |
| Local Persistence | SwiftData |
| Architecture | MVVM + Service Layer |

---

## 🚀 Getting Started

### Requirements
- Xcode 16+
- iOS 18+ (for Apple Foundation Models)
- An LLM API Key (currently using Groq and Gemini for development purpose)

### Installation

```bash
git clone https://github.com/YOUR_USERNAME/medjourney.git
cd medjourney
open MedJourney.xcodeproj
```

### Configuration

1. Duplicate `Config.xcconfig.example` → `Config.xcconfig`
2. Add your Anthropic API key:

```
ANTHROPIC_API_KEY = sk-ant-...
```

3. Build and run on a device or simulator (iOS 18+)

> ⚠️ Apple Foundation Models require an Apple Silicon device or simulator for full functionality. The app gracefully falls back to cloud-only mode on unsupported hardware.

---

## 🗺 Roadmap

- [x] Core journal CRUD with SwiftData persistence  
- [x] Two-layer AI pipeline (on-device extraction → `health_summary.md` → cloud LLM)  
- [x] Vision OCR for checkup document ingestion  
- [x] Daily greeting card from MD file (zero cloud tokens)  
- [ ] Wearable data integration (HealthKit — steps, HRV, sleep)  
- [ ] Streak and habit tracking  
- [x] Export health summary as PDF for doctor visits  
- [ ] Local-only mode (100% on-device for privacy-first users)  
- [ ] App Store release  

---

## 🧩 Design Decisions & Engineering Notes

**Why not just use RAG?**  
RAG works well for large document corpora. For a personal health journal with a single user's bounded history, a curated summary file is simpler, more deterministic, and far cheaper. RAG adds infrastructure overhead (embeddings, vector DB) that isn't justified here.

**Why Apple Foundation Models for Layer 1?**  
Free inference, no latency penalty for structured extraction, and it keeps sensitive raw data on-device. The cloud LLM only ever sees the distilled summary — never the raw "I feel terrible today and here's why" entry text.

**Why rewrite `health_summary.md` instead of appending?**  
Appending grows unbounded and creates stale context. A rewrite strategy keeps the file size constant and forces the system to maintain only what's medically relevant. It's closer to how a doctor would update a patient's chart.

---

## 👤 Author

**Wahyu Herdianto** — Senior iOS Engineer  
6+ years iOS, 5 years as lead engineer on [MyPertamina](https://pertamina.com) (22M+ downloads)  
Currently building MedJourney as an indie project while exploring senior iOS / AI engineer roles.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0A66C2?style=flat&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/fxwh-/)

---


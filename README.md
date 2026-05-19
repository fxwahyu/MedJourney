# MedJourney

> *My mom visits the doctor every few weeks. Every time, the doctor asks "how have you been feeling?" — and every time, she can't quite remember. Was the fatigue worse on Tuesday or Thursday? Did the headache start before or after the new medication? She'd look at me, I'd shrug. We were both guessing.*
>
> *That's why I built this.*

<br>

MedJourney is a personal health journaling iOS app that lets you upload and track your medical checkup results over time, then uses AI to explain what those results actually mean — in plain language, not medical jargon. The goal isn't to replace your doctor. It's to make sure you walk into that appointment with something real to say.

<br>

## What it does

You snap a photo or upload a PDF of your medical result. The app reads it, breaks down each value, flags anything outside the normal range, and gives you a plain-language summary — along with a list of questions worth bringing up with your doctor.

That's it. No social feed. No gamified wellness streaks that make you feel guilty. No "drink more water" notifications. Just your health data, explained clearly, stored privately on your device.

<br>

## Screenshots

> *Coming soon — currently in active development.*

<br>

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| Language | Swift 5.9 | — |
| UI | SwiftUI | Declarative, composable, feels native |
| Architecture | MVVM | Clean separation, easy to test |
| Local storage | SwiftData | First-class Swift persistence, no CoreData boilerplate |
| AI | Claude API (Anthropic) | Best-in-class document understanding, honest about uncertainty |
| File handling | Local Documents directory | Files stay on device, only URLs stored in SwiftData |
| Networking | Custom `APIClient` (async/await) | Generic, protocol-based, reusable across future projects |

No third-party dependencies. No SPM packages. Just the platform.

<br>

## Project structure

```
MedJourney/
├── Core/
│   ├── Network/
│   │   └── APIClient.swift          # Generic API client, Anthropic endpoint, streaming support
│   └── Storage/
│       └── AppDatabase.swift        # SwiftData container, repository pattern, seed data
│
├── DesignSystem/
│   ├── Tokens/
│   │   └── AppTokens.swift          # Colors, spacing, radius, shadows, typography — single source of truth
│   └── Components/
│       ├── Buttons/
│       │   └── AppButton.swift      # Primary, secondary, ghost, icon, chip — all variants
│       ├── Cards/
│       │   └── AppCard.swift        # Surface, tappable, stat, banner, glass, finding row cards
│       ├── Typography/
│       │   └── AppTypography.swift  # Text style modifiers, section headers, empty states, disclaimers
│       └── Fields/
│           └── AppFields.swift      # Text field, textarea, vital input, pain scale selector
│
├── Models/
│   └── Models.swift                 # User, MedicalEntry, AIAnalysis, AppState, Finding, all enums
│
└── Features/
    ├── Home/                        # Home screen — streak, recent entries, AI summary banner
    ├── Entry/                       # New entry flow — file upload, notes, entry type selection
    └── AIAnalysis/                  # AI insights screen — findings, summary, doctor questions
```

Every component in `DesignSystem/` is fully self-contained and has no dependency on the app's domain models. You can copy any of those files into a completely different project and they'll work.

<br>

## Data model

```
User ──────────────────── MedicalEntry ──────────── AIAnalysis
  │                            │                        │
  ├─ streakCount: Int           ├─ fileURL: URL?         ├─ summary: String
  ├─ lastEntryDate: Date?       ├─ fileType: .pdf/.image ├─ findings: [Finding]
  └─ plan: .free / .paid        └─ fileName: String?     └─ doctorQuestions: [String]

Finding  (struct, Codable — stored as JSON in AIAnalysis)
  ├─ label: String         // "Hemoglobin"
  ├─ value: String         // "11.2"
  ├─ unit: String?         // "g/dL"
  ├─ status: .normal / .borderline / .abnormal
  └─ meaning: String       // plain-language explanation
```

Files live in the app's Documents directory. SwiftData only stores the URL — keeping the database lean regardless of how many PDFs the user uploads.

<br>

## Design system

The design system is built to be reusable across projects, not tied to MedJourney specifically. Everything is parameterised.

```swift
// Any button variant, any size, any state — one component
AppButton(title: "Save & ask care team", icon: "stethoscope", variant: .secondary, action: {})

// Cards with fully customisable shadow, radius, background
AppCard(padding: Spacing.lg, radius: Radius.xl, shadow: .elevated) {
    // any content
}

// Consistent spacing with no magic numbers anywhere
VStack(spacing: Spacing.md) { ... }
```

Three colour themes ship with the app — Jade Morning (default), Sunset Peach, Ocean Sky — defined as a complete token set so swapping the theme is one variable change.

<br>

## Networking layer

The `APIClient` is protocol-based and generic. Adding a new API — tomorrow, next project — means defining one `Endpoint` conformance and calling `client.request(endpoint, responseType: ...)`.

```swift
// Define any endpoint
struct MyEndpoint: Endpoint {
    var baseURL: URL    { URL(string: "https://api.example.com")! }
    var path: String    { "/v1/something" }
    var method: HTTPMethod { .post }
    var headers: [String: String] { ["Authorization": "Bearer \(token)"] }
    var body: Encodable? { MyRequestBody(param: "value") }
}

// Call it — fully async, fully typed
let result: MyResponse = try await APIClient.shared.request(MyEndpoint())
```

Streaming is also supported out of the box via `AsyncThrowingStream`, which is how the AI analysis response is delivered token by token.

<br>

## AI integration

Medical checkup results — whether PDF or image — are sent to the Claude API with a structured prompt that instructs it to:

1. Extract each measurable value from the document
2. Identify whether each value is within normal range
3. Explain what each value means in plain language
4. Write a brief overall summary
5. Suggest 3–5 specific questions worth raising with a doctor

Every AI response includes a disclaimer, built into the model itself, that this is an informational overview — not a diagnosis. The framing is deliberate: the app is a tool to help patients have better conversations with real doctors, not to replace those conversations.

Free plan allows 5 AI analyses. Paid plan is unlimited and adds detailed per-value breakdowns from uploaded lab reports.

<br>

## Freemium model

| Feature | Free | Paid |
|---|---|---|
| Journal entries | Unlimited | Unlimited |
| File uploads (PDF / image) | Unlimited | Unlimited |
| AI analysis | 5 lifetime | Unlimited |
| Detailed per-value breakdown | — | ✓ |
| PDF export for doctor | ✓ | ✓ |
| Streak tracking | ✓ | ✓ |

<br>

## Running the project

```bash
git clone https://github.com/yourusername/MedJourney.git
cd MedJourney
open MedJourney.xcodeproj
```

Add your Anthropic API key to a `Config.xcconfig` file (not committed):

```
ANTHROPIC_API_KEY = sk-ant-your-key-here
```

Then reference it in `Info.plist`:
```xml
<key>ANTHROPIC_API_KEY</key>
<string>$(ANTHROPIC_API_KEY)</string>
```

Requires Xcode 15+ and iOS 17+ (SwiftData minimum deployment target).

<br>

## Status

This is an active personal project, not a boilerplate or tutorial follow-along. Features are being built in sequence — networking and the design system are complete, the AI analysis flow is in progress.

| Module | Status |
|---|---|
| Design system (tokens, buttons, cards, fields) | ✅ Complete |
| SwiftData models + repository | ✅ Complete |
| Networking layer + Anthropic integration | ✅ Complete |
| Home screen | 🔨 In progress |
| New entry + file upload flow | 🔨 In progress |
| AI analysis screen | 🔨 In progress |
| PDF export | 📋 Planned |
| Trends / charts screen | 📋 Planned |
| Notifications | 📋 Planned |

<br>

## Why this and not just Notes.app

Notes doesn't know what a creatinine level means. MedJourney does.

More practically: the problem isn't that people don't write things down. It's that what they write down isn't structured or interpreted in a way that's useful at a doctor's appointment. A photo of a lab result sitting in your camera roll doesn't help anyone. A structured summary of what that result means, with the right questions attached, does.

<br>

## Contact

Built by [Your Name](https://yourwebsite.com) · [LinkedIn](https://linkedin.com/in/yourhandle) · [Twitter / X](https://x.com/yourhandle)

If you're working on something in the health-tech or AI space and want to talk, I'm always open to a conversation.

<br>

---

<sub>MedJourney is not a medical device and does not provide medical advice. All AI-generated content is for informational purposes only. Always consult a qualified healthcare professional for medical decisions.</sub>

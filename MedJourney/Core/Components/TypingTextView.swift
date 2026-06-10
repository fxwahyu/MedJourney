//
//  TypingTextView.swift
//  MedJourney
//
//  Components — Typewriter-style cycling text with blinking cursor
//
//  Use case: AI-style placeholder prompts (e.g. "Tell me how you're doing…")
//  that type out, pause, delete, and cycle through the next prompt.
//

import SwiftUI

/// A text view that types its content character-by-character, pauses,
/// deletes it, and cycles through the next prompt — repeating forever.
///
/// Includes a blinking cursor for the AI/chat aesthetic.
struct TypingTextView: View {

    // MARK: - Configuration

    let prompts: [String]
    var typingSpeed: Double = 0.055           // seconds per character while typing
    var deletingSpeed: Double = 0.025         // seconds per character while deleting
    var pauseAfterTyping: Double = 1.8        // seconds to hold the full prompt
    var pauseBetweenPrompts: Double = 0.3     // seconds between prompts
    var font: Font = .system(size: 14)
    var color: Color = AppColors.textTertiary
    /// When false, types the first prompt once and stops — no delete, no cycling.
    var loop: Bool = true
    /// Pass `nil` for unlimited lines (e.g. the AI briefing card).
    var lineLimit: Int? = 1
    /// When false, the first prompt is shown in full immediately with no typing
    /// animation (e.g. a daily briefing the user has already seen). Only meaningful
    /// for one-shot, non-looping content.
    var animated: Bool = true
    /// Called once the (one-shot) text has finished typing, or immediately when
    /// `animated` is false. Lets the caller record that the animation has played.
    var onFinished: (() -> Void)? = nil

    // MARK: - State

    @State private var displayedText: String = ""
    @State private var cursorVisible: Bool = true

    var body: some View {
        HStack(spacing: 1) {
            Text(displayedText)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(lineLimit)
            Text("|")
                .font(font)
                .foregroundStyle(color)
                .opacity(cursorVisible ? 1 : 0)
        }
        .onAppear {
            // Blink the cursor independently of the typing loop
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                cursorVisible = false
            }
        }
        // Key the task to the prompt content so it cleanly restarts (rather than
        // appending) whenever the text changes or the view re-appears.
        .task(id: prompts) {
            await runTypingLoop()
        }
    }

    // MARK: - Animation Loop

    private func runTypingLoop() async {
        guard !prompts.isEmpty else { return }

        // Instant mode: show the full text at once, no per-character typing.
        if !animated {
            displayedText = prompts.first ?? ""
            onFinished?()
            return
        }

        // Always start from a clean slate — prevents a re-run of this task from
        // appending a second copy of the text to whatever is already displayed.
        displayedText = ""
        var index = 0

        while !Task.isCancelled {
            let current = prompts[index]

            // Type out character by character
            for char in current {
                if Task.isCancelled { return }
                displayedText.append(char)
                try? await Task.sleep(for: .seconds(typingSpeed))
            }

            // One-shot mode: stop after the first prompt is fully typed
            if !loop {
                onFinished?()
                return
            }

            // Hold the full prompt
            try? await Task.sleep(for: .seconds(pauseAfterTyping))
            if Task.isCancelled { return }

            // Delete
            while !displayedText.isEmpty {
                if Task.isCancelled { return }
                _ = displayedText.removeLast()
                try? await Task.sleep(for: .seconds(deletingSpeed))
            }

            // Brief pause, then advance to the next prompt
            try? await Task.sleep(for: .seconds(pauseBetweenPrompts))
            index = (index + 1) % prompts.count
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        TypingTextView(prompts: [
            "Tell me how you're doing...",
            "What's been on your mind?",
            "How's your energy today?",
            "Any symptoms to log?"
        ])
        TypingTextView(
            prompts: ["Loading...", "Thinking...", "Analyzing..."],
            font: .system(size: 18, weight: .semibold),
            color: AppColors.brand
        )
    }
    .padding()
    .background(AppColors.background)
}

//
//  LoadingStateView.swift
//  MedJourney
//
//  Components — Reusable loading, empty, and error states
//

import SwiftUI

/// Displays contextual states: loading, empty, or error.
///
/// Usage:
/// ```swift
/// switch viewModel.state {
/// case .loading:
///     LoadingStateView(state: .loading)
/// case .empty:
///     LoadingStateView(state: .empty(
///         title: "No entries yet",
///         message: "Start journaling to see your entries here.",
///         icon: "heart.text.square"
///     ))
/// case .error(let msg):
///     LoadingStateView(state: .error(
///         message: msg,
///         retryAction: { viewModel.fetch() }
///     ))
/// }
/// ```
struct LoadingStateView: View {

    enum State {
        case loading(message: String = "Loading...")
        case empty(title: String, message: String, icon: String = "tray")
        case error(message: String, retryAction: (() -> Void)? = nil)
    }

    let state: State

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            switch state {
            case .loading(let message):
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppColors.brand)
                    .scaleEffect(1.2)
                Text(message)
                    .appFont(.body)
                    .foregroundStyle(AppColors.textSecondary)

            case .empty(let title, let message, let icon):
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.textTertiary)
                Text(title)
                    .appFont(.h3)
                    .foregroundStyle(AppColors.textPrimary)
                Text(message)
                    .appFont(.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

            case .error(let message, let retryAction):
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.accentOrange)
                Text("Something went wrong")
                    .appFont(.h3)
                    .foregroundStyle(AppColors.textPrimary)
                Text(message)
                    .appFont(.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                if let retryAction {
                    AppButton("Try Again", style: .secondary, icon: "arrow.clockwise") {
                        retryAction()
                    }
                }
            }
        }
        .padding(AppSpacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("States") {
    VStack {
        LoadingStateView(state: .empty(
            title: "No entries yet",
            message: "Start journaling to see your entries here.",
            icon: "heart.text.square"
        ))
    }
    .background(AppColors.background)
}

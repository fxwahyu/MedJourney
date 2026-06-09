//
//  AppGradients.swift
//  MedJourney
//
//  Design System — Gradient definitions (Vital Calm)
//

import SwiftUI

/// Pre-defined gradients from the Vital Calm design spec.
///
/// The AI aurora gradient (violet→blue→cyan) is reserved exclusively
/// for AI surfaces to signal intelligence as deliberate magic.
enum AppGradients {

    /// Header gradient — spruce signature (145°).
    static let header = LinearGradient(
        colors: [
            AppColors.brand,
            AppColors.brandDark,
            AppColors.brandDeeper,
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle brand gradient for card backgrounds.
    static let brandSubtle = LinearGradient(
        colors: [
            AppColors.brandPale,
            AppColors.brandSoft.opacity(0.5),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Clay accent gradient for attention-drawing elements.
    static let accent = LinearGradient(
        colors: [
            AppColors.accentOrange,
            AppColors.accentOrange.opacity(0.8),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Aurora gradient for AI surfaces — violet → blue → cyan.
    /// Reserved exclusively for AI moments.
    static let violet = LinearGradient(
        colors: [
            AppColors.accentViolet,
            AppColors.sky,
            AppColors.aiCyan,
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Glass overlay gradient for glassmorphism effects.
    static let glassOverlay = LinearGradient(
        colors: [
            Color.white.opacity(0.25),
            Color.white.opacity(0.08),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Medicine card gradient — rose flow
    static let medicine = LinearGradient(
        colors: [AppColors.rose, AppColors.rosePale],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Checklist card gradient — soft mint
    static let checklist = LinearGradient(
        colors: [AppColors.mintCard, AppColors.mintCardDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Insights card gradient — indigo to soft violet
    static let insights = LinearGradient(
        colors: [AppColors.indigo, AppColors.accentViolet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Checkup card gradient — teal to spruce
    static let checkup = LinearGradient(
        colors: [AppColors.checkupTeal, AppColors.brandDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// AI aurora glow — violet → blue → cyan.
    /// The signature AI gradient; used on all AI-powered surfaces.
    static let aiGlow = LinearGradient(
        colors: [AppColors.accentViolet, AppColors.sky, AppColors.aiCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft AI aurora tint — for card backgrounds on AI surfaces.
    static let aiGlowSoft = LinearGradient(
        colors: [
            AppColors.accentViolet.opacity(0.16),
            AppColors.sky.opacity(0.13),
            AppColors.aiCyan.opacity(0.14),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

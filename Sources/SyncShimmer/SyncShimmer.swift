import SwiftUI

// MARK: - Configuration

/// Global configuration for SyncShimmer placeholders.
public enum SyncShimmerConfig {

    /// Duration of one full sweep cycle in seconds. Default: `1.6`
    public static var duration: Double = 1.6

    /// Fraction of the cycle spent paused before restarting (0...1). Default: `0.02`
    public static var pauseFraction: Double = 0.02

    /// Base color of the placeholder bar (visible between sweeps).
    /// Should be very subtle — just enough to hint at the bar's presence.
    /// Default: adapts to light/dark mode automatically.
    public static var baseColor: Color?

    /// Highlight color of the sweep gradient.
    /// Default: adapts to light/dark mode automatically.
    public static var highlightColor: Color?

    /// Peak opacity of the highlight at the center of the band. Default: `0.55`
    public static var highlightPeakOpacity: Double = 0.55

    /// Opacity at the inner edges of the highlight band. Default: `0.2`
    public static var highlightEdgeOpacity: Double = 0.2

    /// Width of the highlight band as a fraction of the zone width (0...1). Default: `0.45`
    public static var bandFraction: CGFloat = 0.45
}

// MARK: - Zone

/// Defines which zone a placeholder belongs to.
/// All placeholders in the same zone sweep in unison.
/// Different zones sweep their own widths but share the same phase,
/// so they always start and restart together.
public enum ShimmerZone {
    /// Left zone — typically covers the left portion of the screen (default 65%).
    case left

    /// Right zone — typically covers the right portion (default 35%).
    case right

    /// Custom zone with explicit screen-relative start and width fractions (0...1).
    case custom(start: CGFloat, width: CGFloat)

    /// Full screen width — single zone sweep.
    case full
}

// MARK: - Placeholder View

/// A placeholder bar with a synchronized screen-wide shimmer effect.
///
/// All instances sharing the same zone have their highlight band perfectly
/// synchronized — the beam sweeps across the zone in unison.
///
/// ```swift
/// // Basic usage
/// SyncShimmerPlaceholder()
///     .frame(width: 120, height: 14)
///     .clipShape(RoundedRectangle(cornerRadius: 4))
///
/// // Right-side value placeholder
/// SyncShimmerPlaceholder(zone: .right)
///     .frame(width: 40, height: 14)
///     .clipShape(RoundedRectangle(cornerRadius: 4))
///
/// // Synced left + right in one row
/// HStack {
///     SyncShimmerPlaceholder(zone: .left)
///         .frame(width: 100, height: 14)
///     Spacer()
///     SyncShimmerPlaceholder(zone: .right)
///         .frame(width: 40, height: 14)
/// }
/// ```
public struct SyncShimmerPlaceholder: View {

    public let zone: ShimmerZone

    public init(zone: ShimmerZone = .left) {
        self.zone = zone
    }

    @Environment(\.colorScheme) private var colorScheme

    private var baseColor: Color {
        SyncShimmerConfig.baseColor ?? (colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.06))
    }

    private var highlightColor: Color {
        SyncShimmerConfig.highlightColor ?? (colorScheme == .dark
            ? Color.gray.opacity(0.35)
            : Color.gray.opacity(0.25))
    }

    public var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { geo in
                canvas(geo: geo, date: context.date)
            }
        }
    }

    private func canvas(geo: GeometryProxy, date: Date) -> some View {
        let screenWidth = screenWidth()
        let barFrame = geo.frame(in: .global)
        let barWidth = geo.size.width

        // Zone boundaries
        let (zoneStart, zoneWidth) = zoneBounds(screenWidth: screenWidth)
        let bandWidth = zoneWidth * SyncShimmerConfig.bandFraction

        // Global phase (0...1) with pause
        let t = date.timeIntervalSinceReferenceDate
        let rawPhase = t.truncatingRemainder(dividingBy: SyncShimmerConfig.duration) / SyncShimmerConfig.duration
        let activeRange = 1.0 - SyncShimmerConfig.pauseFraction
        let phase = CGFloat(min(rawPhase / activeRange, 1.0))
        let easedPhase = smoothstep(phase)

        // Beam position in screen coords
        let sweepStart = zoneStart - bandWidth * 0.5
        let sweepEnd = zoneStart + zoneWidth + bandWidth * 0.5
        let beamCenter = sweepStart + easedPhase * (sweepEnd - sweepStart)

        // Convert to local (0...1) fraction
        let localCenter = barWidth > 0 ? (beamCenter - barFrame.minX) / barWidth : 0.5
        let halfBand = barWidth > 0 ? (bandWidth * 0.5) / barWidth : 0.2

        return Rectangle()
            .fill(baseColor)
            .overlay(
                LinearGradient(
                    stops: softStops(center: localCenter, halfBand: halfBand),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipped()
    }

    private func zoneBounds(screenWidth: CGFloat) -> (start: CGFloat, width: CGFloat) {
        switch zone {
        case .left:
            return (0, screenWidth * 0.65)
        case .right:
            return (screenWidth * 0.65, screenWidth * 0.35)
        case .custom(let start, let width):
            return (screenWidth * start, screenWidth * width)
        case .full:
            return (0, screenWidth)
        }
    }

    private func softStops(center: CGFloat, halfBand: CGFloat) -> [Gradient.Stop] {
        let outerStart = center - halfBand
        let innerStart = center - halfBand * 0.35
        let innerEnd = center + halfBand * 0.35
        let outerEnd = center + halfBand

        let peak = SyncShimmerConfig.highlightPeakOpacity
        let edge = SyncShimmerConfig.highlightEdgeOpacity

        return [
            .init(color: .clear, location: clamp(outerStart)),
            .init(color: highlightColor.opacity(edge), location: clamp(innerStart)),
            .init(color: highlightColor.opacity(peak), location: clamp(center)),
            .init(color: highlightColor.opacity(edge), location: clamp(innerEnd)),
            .init(color: .clear, location: clamp(outerEnd)),
        ]
    }

    private func clamp(_ v: CGFloat) -> CGFloat { max(0, min(1, v)) }
    private func smoothstep(_ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, x))
        return t * t * (3 - 2 * t)
    }

    private func screenWidth() -> CGFloat {
        #if os(iOS)
        UIScreen.main.bounds.width
        #else
        NSScreen.main?.frame.width ?? 400
        #endif
    }
}

// MARK: - View Extension

public extension View {
    /// Applies a synchronized shimmer overlay to this view.
    /// Uses the view itself as the base, with the shimmer gradient on top.
    func syncShimmer(zone: ShimmerZone = .full, active: Bool = true) -> some View {
        overlay {
            if active {
                SyncShimmerPlaceholder(zone: zone)
                    .allowsHitTesting(false)
            }
        }
    }
}

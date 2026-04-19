import AppKit
import Foundation
import Metal
import MetalKit

private struct OverlayBadgeState {
    let text: String
}

@MainActor
final class OverlayController {
    private enum FlashDuration {
        static let seconds: TimeInterval = 0.8
    }

    private struct OverlayContentState {
        let screen: NSScreen
        let slots: [ResolvedTriggerSlot]
        let highlightFrame: CGRect?
        let hoveredLayoutID: String?
        let badge: OverlayBadgeState?
        let configuration: AppConfiguration
    }

    private var panel: OverlayPanel?
    private var screenIdentifier: String?
    private var flashGeneration: UInt64 = 0
    private var badgeGeneration: UInt64 = 0
    private var pendingPostFlashOverlayState: OverlayContentState?

    func update(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badgeText: String? = nil
    ) {
        cancelPendingFlash()

        if shouldRenderOverlay(configuration: configuration, badgeText: badgeText) {
            showOverlay(
                screen: screen,
                slots: slots,
                highlightFrame: highlightFrame,
                hoveredLayoutID: hoveredLayoutID,
                configuration: configuration,
                badge: badgeText.map { OverlayBadgeState(text: $0) }
            )
        } else {
            dismissPanel()
        }
    }

    func flashHighlight(
        frame: CGRect,
        screen: NSScreen,
        slots: [ResolvedTriggerSlot] = [],
        configuration: AppConfiguration,
        keepsOverlayVisibleAfterFlash: Bool = false
    ) {
        cancelPendingFlash()

        guard configuration.appearance.renderWindowHighlight else {
            if keepsOverlayVisibleAfterFlash {
                showOverlay(
                    screen: screen,
                    slots: slots,
                    highlightFrame: frame,
                    hoveredLayoutID: nil,
                    configuration: configuration
                )
            } else {
                dismissPanel()
            }
            return
        }

        let steadyState = OverlayContentState(
            screen: screen,
            slots: slots,
            highlightFrame: frame,
            hoveredLayoutID: nil,
            badge: nil,
            configuration: configuration
        )
        pendingPostFlashOverlayState = keepsOverlayVisibleAfterFlash ? steadyState : nil
        showOverlay(
            screen: steadyState.screen,
            slots: steadyState.slots,
            highlightFrame: steadyState.highlightFrame,
            hoveredLayoutID: steadyState.hoveredLayoutID,
            configuration: steadyState.configuration,
            badge: steadyState.badge
        )
        panel?.alphaValue = 1.0

        flashGeneration &+= 1
        let expectedGeneration = flashGeneration

        NSAnimationContext.runAnimationGroup { context in
            context.duration = FlashDuration.seconds
            self.panel?.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.flashGeneration == expectedGeneration {
                    if let pendingPostFlashOverlayState = self.pendingPostFlashOverlayState {
                        self.panel?.alphaValue = 1.0
                        self.showOverlay(
                            screen: pendingPostFlashOverlayState.screen,
                            slots: pendingPostFlashOverlayState.slots,
                            highlightFrame: pendingPostFlashOverlayState.highlightFrame,
                            hoveredLayoutID: pendingPostFlashOverlayState.hoveredLayoutID,
                            configuration: pendingPostFlashOverlayState.configuration,
                            badge: pendingPostFlashOverlayState.badge
                        )
                        self.pendingPostFlashOverlayState = nil
                    } else {
                        self.dismissPanel()
                    }
                }
            }
        }
    }

    func flashGroupLabel(
        text: String,
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        configuration: AppConfiguration,
        keepsOverlayVisibleAfterFlash: Bool
    ) {
        showOverlay(
            screen: screen,
            slots: slots,
            highlightFrame: highlightFrame,
            hoveredLayoutID: nil,
            configuration: configuration,
            badge: OverlayBadgeState(text: text)
        )

        badgeGeneration &+= 1
        let expectedGeneration = badgeGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + FlashDuration.seconds) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard self.badgeGeneration == expectedGeneration else { return }

                if keepsOverlayVisibleAfterFlash {
                    self.showOverlay(
                        screen: screen,
                        slots: slots,
                        highlightFrame: highlightFrame,
                        hoveredLayoutID: nil,
                        configuration: configuration,
                        badge: nil
                    )
                } else {
                    self.dismissPanel()
                }
            }
        }
    }

    func dismiss() {
        cancelPendingFlash()
        dismissPanel()
    }

    private func cancelPendingFlash() {
        flashGeneration &+= 1
        badgeGeneration &+= 1
        pendingPostFlashOverlayState = nil
        panel?.alphaValue = 1.0
    }

    private func shouldRenderOverlay(
        configuration: AppConfiguration,
        badgeText: String?
    ) -> Bool {
        configuration.appearance.renderTriggerAreas
            || configuration.appearance.renderWindowHighlight
            || badgeText != nil
    }

    private func showOverlay(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badge: OverlayBadgeState? = nil
    ) {
        let identifier = Geometry.screenIdentifier(for: screen)
        if panel == nil || screenIdentifier != identifier {
            dismissPanel()
            let panel = OverlayPanel(contentRect: screen.frame)
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            self.panel = panel
            screenIdentifier = identifier
        } else {
            panel?.setFrame(screen.frame, display: true)
        }

        let overlayView: MetalOverlayView
        if let currentView = panel?.contentView as? MetalOverlayView {
            overlayView = currentView
        } else {
            overlayView = MetalOverlayView(
                frame: NSRect(origin: .zero, size: screen.frame.size)
            )
            panel?.contentView = overlayView
        }

        overlayView.frame = NSRect(origin: .zero, size: screen.frame.size)
        overlayView.screenOrigin = screen.frame.origin
        overlayView.resolvedSlots = slots
        overlayView.highlightFrame = highlightFrame
        overlayView.hoveredLayoutID = hoveredLayoutID
        overlayView.configuration = configuration
        overlayView.badgeText = badge?.text
        overlayView.needsDisplay = true
    }

    private func dismissPanel() {
        panel?.orderOut(nil)
        panel = nil
        screenIdentifier = nil
        pendingPostFlashOverlayState = nil
        badgeGeneration &+= 1
    }
}

// MARK: - Overlay Panel

@MainActor
private final class OverlayPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        hasShadow = false
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Metal Overlay View

/// Replaces the old `OverlayView` (NSView + NSBezierPath) with an MTKView
/// that renders trigger regions, window highlights, and badge labels using
/// GPU-accelerated SDF rounded-rectangle shaders.
@MainActor
private final class MetalOverlayView: MTKView {

    // MARK: Public state (set by OverlayController)

    var screenOrigin: CGPoint = .zero
    var resolvedSlots: [ResolvedTriggerSlot] = []
    var highlightFrame: CGRect?
    var hoveredLayoutID: String?
    var configuration: AppConfiguration = .defaultValue
    var badgeText: String?

    // MARK: Private

    private let renderer: MetalOverlayRenderer?
    private static let overlayCornerRadius: CGFloat = 10

    // MARK: Init

    init(frame: NSRect) {
        let renderer = MetalOverlayRenderer()
        self.renderer = renderer

        // When Metal is unavailable (e.g. in tests), pass nil device;
        // MTKView still creates a valid NSView but draw() will no-op
        // because the renderer guard fails.
        super.init(frame: frame, device: renderer?.device)

        commonInit()
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func commonInit() {
        // Only redraw when explicitly requested (needsDisplay = true).
        isPaused = true
        enableSetNeedsDisplay = true

        // Transparent background so the desktop shows through.
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        layer?.isOpaque = false

        colorPixelFormat = .bgra8Unorm
    }

    override var isOpaque: Bool { false }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let renderer else { return }

        let scale = window?.backingScaleFactor ?? 2.0
        var rects: [OverlayRoundedRect] = []

        // --- trigger regions ---
        if configuration.appearance.renderTriggerAreas {
            let visibleSlots: [ResolvedTriggerSlot] = switch configuration.appearance.triggerHighlightMode {
            case .all:
                resolvedSlots
            case .current:
                resolvedSlots.filter { $0.layoutID == hoveredLayoutID }
            case .none:
                []
            }

            let appearance = configuration.appearance
            let triggerColor = appearance.triggerStrokeColor
            let triggerStrokeWidth = SettingsPreviewSupport.triggerStrokeWidth(for: appearance)

            for slot in visibleSlots {
                for hitTestFrame in slot.hitTestFrames {
                    rects.append(makeRoundedRect(
                        globalFrame: hitTestFrame,
                        fillColor: triggerColor,
                        fillOpacity: appearance.triggerFillOpacity,
                        strokeColor: triggerColor,
                        strokeWidth: triggerStrokeWidth,
                        cornerRadius: Self.overlayCornerRadius,
                        scale: scale
                    ))
                }
            }
        }

        // --- window highlight ---
        if configuration.appearance.renderWindowHighlight, let highlightFrame {
            let appearance = configuration.appearance
            let highlightColor = appearance.highlightStrokeColor
            let highlightStrokeWidth = SettingsPreviewSupport.windowHighlightStrokeWidth(for: appearance)

            rects.append(makeRoundedRect(
                globalFrame: highlightFrame,
                fillColor: highlightColor,
                fillOpacity: appearance.highlightFillOpacity,
                strokeColor: highlightColor,
                strokeWidth: highlightStrokeWidth,
                cornerRadius: Self.overlayCornerRadius,
                scale: scale
            ))
        }

        // --- badge ---
        var badgeTexture: MTLTexture?
        var badgeRectSIMD: SIMD4<Float>?

        if let badgeText, !badgeText.isEmpty {
            let targetRect = highlightFrame.map(localRect(from:))
                ?? bounds.insetBy(dx: 48, dy: 48)
            let badgeInfo = Self.computeBadgeRect(text: badgeText, in: targetRect)

            badgeTexture = renderer.makeBadgeTexture(
                text: badgeText,
                badgeSize: badgeInfo.size,
                scaleFactor: scale
            )
            badgeRectSIMD = SIMD4<Float>(
                Float(badgeInfo.origin.x * scale),
                Float(badgeInfo.origin.y * scale),
                Float(badgeInfo.width * scale),
                Float(badgeInfo.height * scale)
            )
        }

        renderer.draw(
            in: self,
            rects: rects,
            badgeTexture: badgeTexture,
            badgeRect: badgeRectSIMD
        )
    }

    // MARK: - Helpers

    private func localRect(from globalRect: CGRect) -> CGRect {
        CGRect(
            x: globalRect.origin.x - screenOrigin.x,
            y: globalRect.origin.y - screenOrigin.y,
            width: globalRect.width,
            height: globalRect.height
        )
    }

    /// Convert an appearance colour + opacity into an `OverlayRoundedRect`.
    private func makeRoundedRect(
        globalFrame: CGRect,
        fillColor: RGBAColor,
        fillOpacity: Double,
        strokeColor: RGBAColor,
        strokeWidth: CGFloat?,
        cornerRadius: CGFloat,
        scale: CGFloat
    ) -> OverlayRoundedRect {
        let local = localRect(from: globalFrame)
        return OverlayRoundedRect(
            rect: SIMD4<Float>(
                Float(local.origin.x * scale),
                Float(local.origin.y * scale),
                Float(local.width * scale),
                Float(local.height * scale)
            ),
            fillColor: SIMD4<Float>(
                Float(fillColor.red),
                Float(fillColor.green),
                Float(fillColor.blue),
                Float(fillOpacity)
            ),
            strokeColor: SIMD4<Float>(
                Float(strokeColor.red),
                Float(strokeColor.green),
                Float(strokeColor.blue),
                Float(strokeColor.alpha)
            ),
            cornerRadius: Float(cornerRadius * scale),
            strokeWidth: Float((strokeWidth ?? 0) * scale)
        )
    }

    /// Compute the badge CGRect (in local view coordinates) for the given
    /// text, mirroring the original `OverlayView.drawBadge` layout.
    private static func computeBadgeRect(text: String, in targetRect: CGRect) -> CGRect {
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = NSAttributedString(string: text, attributes: textAttributes).size()
        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 10
        return CGRect(
            x: targetRect.midX - ((textSize.width + horizontalPadding * 2) / 2),
            y: targetRect.midY - ((textSize.height + verticalPadding * 2) / 2),
            width: textSize.width + horizontalPadding * 2,
            height: textSize.height + verticalPadding * 2
        )
    }
}

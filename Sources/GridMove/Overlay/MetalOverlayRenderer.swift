import AppKit
import Foundation
import Metal
import MetalKit
import QuartzCore

@MainActor
final class MetalOverlayRenderer: OverlayRenderer {
    private var panel: MetalOverlayPanel?
    private var screenIdentifier: String?
    private var metalResources: MetalResources?

    var overlayPanel: NSPanel? { panel }

    func show(
        on screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badge: OverlayBadgeState?
    ) {
        let identifier = Geometry.screenIdentifier(for: screen)
        if panel == nil || screenIdentifier != identifier {
            dismissInternal()
            let newPanel = MetalOverlayPanel(contentRect: screen.frame)
            newPanel.setFrame(screen.frame, display: true)
            newPanel.orderFrontRegardless()
            panel = newPanel
            screenIdentifier = identifier
        } else {
            panel?.setFrame(screen.frame, display: true)
        }

        guard let contentView = panel?.contentView else { return }
        contentView.frame = NSRect(origin: .zero, size: screen.frame.size)

        let screenOrigin = screen.frame.origin
        let appearance = configuration.appearance

        var rects: [OverlayRectDescriptor] = []

        if appearance.renderTriggerAreas {
            rects.append(
                contentsOf: triggerRectDescriptors(
                    slots: slots,
                    hoveredLayoutID: hoveredLayoutID,
                    appearance: appearance,
                    screenOrigin: screenOrigin
                )
            )
        }

        if appearance.renderWindowHighlight, let highlightFrame {
            rects.append(
                highlightRectDescriptor(
                    frame: highlightFrame,
                    appearance: appearance,
                    screenOrigin: screenOrigin
                )
            )
        }

        if let badge {
            rects.append(
                badgeBackgroundDescriptor(
                    text: badge.text,
                    highlightFrame: highlightFrame,
                    screenOrigin: screenOrigin,
                    viewBounds: contentView.bounds
                )
            )
        }

        let metalView = ensureMetalView(in: contentView, size: screen.frame.size)
        renderRects(rects, into: metalView, viewSize: contentView.bounds.size)

        if let badge {
            updateBadgeTextLayer(
                in: contentView.layer!,
                text: badge.text,
                highlightFrame: highlightFrame,
                screenOrigin: screenOrigin,
                viewBounds: contentView.bounds
            )
        } else {
            removeBadgeTextLayer(from: contentView.layer)
        }
    }

    func dismiss() {
        dismissInternal()
    }

    private func dismissInternal() {
        panel?.orderOut(nil)
        panel = nil
        screenIdentifier = nil
        metalResources = nil
    }

    private func ensureMetalView(in contentView: NSView, size: CGSize) -> MTKView {
        if let existing = contentView.subviews.first(where: { $0 is MTKView }) as? MTKView {
            existing.frame = NSRect(origin: .zero, size: size)
            return existing
        }

        let device = metalResources?.device ?? MTLCreateSystemDefaultDevice()
        guard let device else {
            let fallback = MTKView(frame: NSRect(origin: .zero, size: size))
            contentView.addSubview(fallback)
            return fallback
        }

        if metalResources == nil {
            metalResources = MetalResources(device: device)
        }

        let mtkView = MTKView(frame: NSRect(origin: .zero, size: size), device: device)
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = false
        mtkView.layer?.isOpaque = false
        mtkView.layer?.backgroundColor = NSColor.clear.cgColor
        (mtkView.layer as? CAMetalLayer)?.pixelFormat = .bgra8Unorm
        contentView.addSubview(mtkView)
        return mtkView
    }

    private func renderRects(_ rects: [OverlayRectDescriptor], into mtkView: MTKView, viewSize: CGSize) {
        guard let resources = metalResources,
              let drawable = (mtkView.layer as? CAMetalLayer)?.nextDrawable(),
              let commandBuffer = resources.commandQueue.makeCommandBuffer()
        else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipelineState = resources.pipelineState
        else {
            commandBuffer.commit()
            return
        }

        encoder.setRenderPipelineState(pipelineState)

        var projectionMatrix = orthographicMatrix(width: Float(viewSize.width), height: Float(viewSize.height))
        encoder.setVertexBytes(&projectionMatrix, length: MemoryLayout<simd_float4x4>.size, index: 1)

        for rect in rects {
            renderRect(rect, encoder: encoder)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func renderRect(_ descriptor: OverlayRectDescriptor, encoder: MTLRenderCommandEncoder) {
        let frame = descriptor.frame
        let vertices: [Float] = [
            Float(frame.minX), Float(frame.minY), 0, 0,
            Float(frame.maxX), Float(frame.minY), 1, 0,
            Float(frame.minX), Float(frame.maxY), 0, 1,
            Float(frame.maxX), Float(frame.maxY), 1, 1,
        ]

        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Float>.size, index: 0)

        var params = MetalRectParams(
            fillColor: descriptor.fillColor,
            strokeColor: descriptor.strokeColor,
            strokeWidth: descriptor.strokeWidth,
            cornerRadius: descriptor.cornerRadius,
            rectSize: SIMD2<Float>(Float(frame.width), Float(frame.height))
        )
        encoder.setFragmentBytes(&params, length: MemoryLayout<MetalRectParams>.size, index: 0)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    private func orthographicMatrix(width: Float, height: Float) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(2.0 / width, 0, 0, 0),
            SIMD4<Float>(0, 2.0 / height, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(-1, -1, 0, 1)
        ))
    }

    private func triggerRectDescriptors(
        slots: [ResolvedTriggerSlot],
        hoveredLayoutID: String?,
        appearance: AppearanceSettings,
        screenOrigin: CGPoint
    ) -> [OverlayRectDescriptor] {
        let visibleSlots: [ResolvedTriggerSlot] = switch appearance.triggerHighlightMode {
        case .all:
            slots
        case .current:
            slots.filter { $0.layoutID == hoveredLayoutID }
        case .none:
            []
        }

        let color = appearance.triggerStrokeColor.nsColor
        let fillColor = color.withAlphaComponent(appearance.triggerFillOpacity)
        let strokeWidth = SettingsPreviewSupport.triggerStrokeWidth(for: appearance)

        return visibleSlots.flatMap { slot in
            slot.hitTestFrames.map { hitTestFrame in
                OverlayRectDescriptor(
                    frame: localRect(from: hitTestFrame, screenOrigin: screenOrigin),
                    fillColor: simdColor(fillColor),
                    strokeColor: strokeWidth != nil ? simdColor(color) : SIMD4<Float>(0, 0, 0, 0),
                    strokeWidth: Float(strokeWidth ?? 0),
                    cornerRadius: 10
                )
            }
        }
    }

    private func highlightRectDescriptor(
        frame: CGRect,
        appearance: AppearanceSettings,
        screenOrigin: CGPoint
    ) -> OverlayRectDescriptor {
        let color = appearance.highlightStrokeColor.nsColor
        let strokeWidth = SettingsPreviewSupport.windowHighlightStrokeWidth(for: appearance)

        return OverlayRectDescriptor(
            frame: localRect(from: frame, screenOrigin: screenOrigin),
            fillColor: simdColor(color.withAlphaComponent(appearance.highlightFillOpacity)),
            strokeColor: strokeWidth != nil ? simdColor(color) : SIMD4<Float>(0, 0, 0, 0),
            strokeWidth: Float(strokeWidth ?? 0),
            cornerRadius: 10
        )
    }

    private func badgeBackgroundDescriptor(
        text: String,
        highlightFrame: CGRect?,
        screenOrigin: CGPoint,
        viewBounds: CGRect
    ) -> OverlayRectDescriptor {
        let (badgeFrame, _) = badgeLayout(
            text: text,
            highlightFrame: highlightFrame,
            screenOrigin: screenOrigin,
            viewBounds: viewBounds
        )

        return OverlayRectDescriptor(
            frame: badgeFrame,
            fillColor: SIMD4<Float>(0, 0, 0, 0.72),
            strokeColor: SIMD4<Float>(0, 0, 0, 0),
            strokeWidth: 0,
            cornerRadius: 12
        )
    }

    private func updateBadgeTextLayer(
        in rootLayer: CALayer,
        text: String,
        highlightFrame: CGRect?,
        screenOrigin: CGPoint,
        viewBounds: CGRect
    ) {
        let (badgeFrame, textSize) = badgeLayout(
            text: text,
            highlightFrame: highlightFrame,
            screenOrigin: screenOrigin,
            viewBounds: viewBounds
        )

        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 10

        let textLayer: CATextLayer
        if let existing = rootLayer.sublayers?.first(where: { $0.name == "badge-text" }) as? CATextLayer {
            textLayer = existing
        } else {
            textLayer = CATextLayer()
            textLayer.name = "badge-text"
            textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            rootLayer.addSublayer(textLayer)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        textLayer.frame = CGRect(
            x: badgeFrame.minX + horizontalPadding,
            y: badgeFrame.minY + verticalPadding,
            width: textSize.width,
            height: textSize.height
        )
        textLayer.string = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
        )

        CATransaction.commit()
    }

    private func removeBadgeTextLayer(from layer: CALayer?) {
        layer?.sublayers?.first(where: { $0.name == "badge-text" })?.removeFromSuperlayer()
    }

    private func badgeLayout(
        text: String,
        highlightFrame: CGRect?,
        screenOrigin: CGPoint,
        viewBounds: CGRect
    ) -> (CGRect, CGSize) {
        let targetRect: CGRect
        if let highlightFrame {
            targetRect = localRect(from: highlightFrame, screenOrigin: screenOrigin)
        } else {
            targetRect = viewBounds.insetBy(dx: 48, dy: 48)
        }

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = NSAttributedString(string: text, attributes: textAttributes).size()
        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 10
        let badgeSize = CGSize(
            width: textSize.width + horizontalPadding * 2,
            height: textSize.height + verticalPadding * 2
        )
        let badgeOrigin = CGPoint(
            x: targetRect.midX - badgeSize.width / 2,
            y: targetRect.midY - badgeSize.height / 2
        )

        return (CGRect(origin: badgeOrigin, size: badgeSize), textSize)
    }

    private func simdColor(_ color: NSColor) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let converted = color.usingColorSpace(.sRGB) ?? color
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }

    private func localRect(from globalRect: CGRect, screenOrigin: CGPoint) -> CGRect {
        CGRect(
            x: globalRect.origin.x - screenOrigin.x,
            y: globalRect.origin.y - screenOrigin.y,
            width: globalRect.width,
            height: globalRect.height
        )
    }
}

private struct OverlayRectDescriptor {
    let frame: CGRect
    let fillColor: SIMD4<Float>
    let strokeColor: SIMD4<Float>
    let strokeWidth: Float
    let cornerRadius: Float
}

private struct MetalRectParams {
    let fillColor: SIMD4<Float>
    let strokeColor: SIMD4<Float>
    let strokeWidth: Float
    let cornerRadius: Float
    let rectSize: SIMD2<Float>
}

@MainActor
private final class MetalResources {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState?

    init(device: MTLDevice) {
        self.device = device
        commandQueue = device.makeCommandQueue()!

        var state: MTLRenderPipelineState?
        if let library = try? device.makeDefaultLibrary(bundle: Bundle.main) {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "overlayVertexShader")
            descriptor.fragmentFunction = library.makeFunction(name: "overlayFragmentShader")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float2
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 2
            vertexDescriptor.attributes[1].bufferIndex = 0
            vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 4
            descriptor.vertexDescriptor = vertexDescriptor

            state = try? device.makeRenderPipelineState(descriptor: descriptor)
        }
        pipelineState = state
    }
}

@MainActor
private final class MetalOverlayPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .nonretained,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        hasShadow = false
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let view = NSView(frame: NSRect(origin: .zero, size: contentRect.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

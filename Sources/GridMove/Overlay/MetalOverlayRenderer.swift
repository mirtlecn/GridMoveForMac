import AppKit
import Metal
import MetalKit

// MARK: - GPU Data Types

/// Per-instance data for the rounded-rect SDF shader.
/// Layout must match the Metal shader struct exactly (64 bytes stride).
struct OverlayRoundedRect {
    var rect: SIMD4<Float>        // x, y, width, height in pixels
    var fillColor: SIMD4<Float>   // RGBA non-premultiplied (shader premultiplies)
    var strokeColor: SIMD4<Float> // RGBA non-premultiplied (shader premultiplies)
    var cornerRadius: Float
    var strokeWidth: Float
    private var _pad0: Float = 0
    private var _pad1: Float = 0
}

// MARK: - Metal Overlay Renderer

/// Manages the Metal pipeline state and performs overlay drawing.
///
/// All rounded rectangles (trigger regions, window highlights, badge backgrounds)
/// are drawn using a signed-distance-field (SDF) fragment shader with instanced
/// quads.  Badge text is rasterised into a small texture via Core Graphics and
/// composited with a second textured-quad draw call.
@MainActor
final class MetalOverlayRenderer {

    // MARK: - Properties

    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let roundedRectPipeline: MTLRenderPipelineState
    private let texturedQuadPipeline: MTLRenderPipelineState

    // MARK: - Initialisation

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue()
        else { return nil }

        self.device = device
        self.commandQueue = commandQueue

        guard let library = try? device.makeLibrary(source: Self.shaderSource, options: nil) else {
            return nil
        }

        // --- rounded-rect pipeline ---
        guard let rrVert = library.makeFunction(name: "roundedRectVertex"),
              let rrFrag = library.makeFunction(name: "roundedRectFragment")
        else { return nil }

        let rrDesc = MTLRenderPipelineDescriptor()
        rrDesc.vertexFunction = rrVert
        rrDesc.fragmentFunction = rrFrag
        rrDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        Self.configureAlphaBlending(rrDesc.colorAttachments[0]!)

        guard let rrState = try? device.makeRenderPipelineState(descriptor: rrDesc) else {
            return nil
        }
        self.roundedRectPipeline = rrState

        // --- textured-quad pipeline ---
        guard let tqVert = library.makeFunction(name: "texturedQuadVertex"),
              let tqFrag = library.makeFunction(name: "texturedQuadFragment")
        else { return nil }

        let tqDesc = MTLRenderPipelineDescriptor()
        tqDesc.vertexFunction = tqVert
        tqDesc.fragmentFunction = tqFrag
        tqDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        Self.configureAlphaBlending(tqDesc.colorAttachments[0]!)

        guard let tqState = try? device.makeRenderPipelineState(descriptor: tqDesc) else {
            return nil
        }
        self.texturedQuadPipeline = tqState
    }

    // MARK: - Drawing

    /// Maximum payload for setVertexBytes (Metal limit: 4 096 bytes).
    private static let maxInlineBytes = 4096

    func draw(
        in view: MTKView,
        rects: [OverlayRoundedRect],
        badgeTexture: MTLTexture?,
        badgeRect: SIMD4<Float>?
    ) {
        guard let drawable = view.currentDrawable,
              let passDesc = view.currentRenderPassDescriptor,
              let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc)
        else { return }

        let viewportSize = SIMD2<Float>(
            Float(view.drawableSize.width),
            Float(view.drawableSize.height)
        )

        // 1) Draw rounded rects (instanced)
        if !rects.isEmpty {
            encoder.setRenderPipelineState(roundedRectPipeline)

            var vp = viewportSize
            encoder.setVertexBytes(&vp, length: MemoryLayout<SIMD2<Float>>.size, index: 0)

            let dataLength = MemoryLayout<OverlayRoundedRect>.stride * rects.count
            if dataLength <= Self.maxInlineBytes {
                var instances = rects
                encoder.setVertexBytes(&instances, length: dataLength, index: 1)
            } else if let buffer = device.makeBuffer(
                bytes: rects,
                length: dataLength,
                options: .storageModeShared
            ) {
                encoder.setVertexBuffer(buffer, offset: 0, index: 1)
            }

            encoder.drawPrimitives(
                type: .triangle,
                vertexStart: 0,
                vertexCount: 6,
                instanceCount: rects.count
            )
        }

        // 2) Draw badge texture
        if let badgeTexture, var rect = badgeRect {
            encoder.setRenderPipelineState(texturedQuadPipeline)

            var vp = viewportSize
            encoder.setVertexBytes(&vp, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
            encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 1)
            encoder.setFragmentTexture(badgeTexture, index: 0)

            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }

        encoder.endEncoding()
        cmdBuf.present(drawable)
        cmdBuf.commit()
    }

    // MARK: - Badge Texture

    /// Rasterise badge text (with its rounded-rect background) into a small
    /// Metal texture using Core Graphics so that only a tiny upload is needed.
    func makeBadgeTexture(
        text: String,
        badgeSize: CGSize,
        scaleFactor: CGFloat
    ) -> MTLTexture? {
        let pixelW = Int(ceil(badgeSize.width * scaleFactor))
        let pixelH = Int(ceil(badgeSize.height * scaleFactor))
        guard pixelW > 0, pixelH > 0 else { return nil }

        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 10

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let attrText = NSAttributedString(string: text, attributes: textAttributes)
        let textSize = attrText.size()

        // Draw into an NSBitmapImageRep (RGBA, 8-bit)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelW,
            pixelsHigh: pixelH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pixelW * 4,
            bitsPerPixel: 32
        ) else { return nil }

        rep.size = badgeSize // logical (point) size

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        let localRect = CGRect(origin: .zero, size: badgeSize)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: localRect, xRadius: 12, yRadius: 12).fill()

        let textRect = CGRect(
            x: horizontalPadding,
            y: (badgeSize.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attrText.draw(in: textRect)

        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.bitmapData else { return nil }

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: pixelW,
            height: pixelH,
            mipmapped: false
        )
        desc.usage = .shaderRead

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }
        texture.replace(
            region: MTLRegionMake2D(0, 0, pixelW, pixelH),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: pixelW * 4
        )
        return texture
    }

    // MARK: - Helpers

    private static func configureAlphaBlending(
        _ attachment: MTLRenderPipelineColorAttachmentDescriptor
    ) {
        attachment.isBlendingEnabled = true
        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.sourceAlphaBlendFactor = .sourceAlpha
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
    }
}

// MARK: - Metal Shading Language Source

extension MetalOverlayRenderer {

    // swiftlint:disable line_length
    nonisolated static let shaderSource: String = """
    #include <metal_stdlib>
    using namespace metal;

    // ----------------------------------------------------------------
    // Shared types
    // ----------------------------------------------------------------

    struct Uniforms {
        float2 viewportSize;   // drawable size in pixels
    };

    // Must match Swift `OverlayRoundedRect` layout (64-byte stride).
    struct RoundedRectInstance {
        packed_float4 rect;          // x  y  w  h   (pixels)
        packed_float4 fillColor;     // RGBA non-premultiplied; shader premultiplies
        packed_float4 strokeColor;   // RGBA non-premultiplied; shader premultiplies
        float         cornerRadius;
        float         strokeWidth;
        float         _pad0;
        float         _pad1;
    };

    // ----------------------------------------------------------------
    // Rounded-rect SDF pipeline
    // ----------------------------------------------------------------

    struct RRVertexOut {
        float4 position [[position]];
        float2 localPos;       // pixel offset from rect centre
        float2 rectSize;       // w, h in pixels
        float4 fillColor;
        float4 strokeColor;
        float  cornerRadius;
        float  strokeWidth;
    };

    vertex RRVertexOut roundedRectVertex(
        uint vid        [[vertex_id]],
        uint iid        [[instance_id]],
        constant Uniforms            &uniforms  [[buffer(0)]],
        constant RoundedRectInstance *instances  [[buffer(1)]]
    ) {
        RoundedRectInstance inst = instances[iid];
        float2 origin = float2(inst.rect[0], inst.rect[1]);
        float2 size   = float2(inst.rect[2], inst.rect[3]);

        // Expand each quad by 1 pixel on every side so the SDF smoothstep
        // anti-aliasing has room to fade to zero without hard clipping.
        float expand = 1.0;
        float2 expOrigin = origin - expand;
        float2 expSize   = size   + expand * 2.0;

        // Six vertices → two triangles covering the expanded quad
        float2 corners[6] = {
            float2(0,0), float2(1,0), float2(0,1),
            float2(1,0), float2(1,1), float2(0,1)
        };

        float2 pos = expOrigin + corners[vid] * expSize;

        // Pixel → clip space.  AppKit Y-up matches Metal clip Y-up.
        float2 clip = (pos / uniforms.viewportSize) * 2.0 - 1.0;

        RRVertexOut out;
        out.position     = float4(clip, 0.0, 1.0);
        out.rectSize     = size;
        out.localPos     = (corners[vid] * expSize - expand) - size * 0.5;
        out.fillColor    = float4(inst.fillColor);
        out.strokeColor  = float4(inst.strokeColor);
        out.cornerRadius = inst.cornerRadius;
        out.strokeWidth  = inst.strokeWidth;
        return out;
    }

    // Signed-distance of a rounded rectangle centred at the origin.
    float sdRoundedRect(float2 p, float2 halfSize, float r) {
        float2 d = abs(p) - halfSize + r;
        return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
    }

    fragment float4 roundedRectFragment(RRVertexOut in [[stage_in]]) {
        float2 half = in.rectSize * 0.5;
        float sdf = sdRoundedRect(in.localPos, half, in.cornerRadius);

        // Anti-aliased fill mask (1 inside, 0 outside, smooth at boundary)
        float fillMask = smoothstep(0.5, -0.5, sdf);

        float4 fc = in.fillColor;
        float4 color = float4(fc.rgb, 1.0) * fc.a * fillMask;

        // Stroke band
        if (in.strokeWidth > 0.0) {
            float strokeDist = abs(sdf) - in.strokeWidth * 0.5;
            float strokeMask = smoothstep(0.5, -0.5, strokeDist);

            float4 sc = in.strokeColor;
            float sA = sc.a * strokeMask;
            // Source-over composite stroke on top of fill
            color.rgb = sc.rgb * sA + color.rgb * (1.0 - sA);
            color.a   = sA + color.a * (1.0 - sA);
        }

        // Discard nearly-invisible fragments to avoid blending artefacts
        // and save fill-rate.  0.002 ≈ 1/512, below the 8-bit precision
        // of the render target.
        if (color.a < 0.002) discard_fragment();
        return color;
    }

    // ----------------------------------------------------------------
    // Textured-quad pipeline  (badge text)
    // ----------------------------------------------------------------

    struct TQVertexOut {
        float4 position [[position]];
        float2 texCoord;
    };

    vertex TQVertexOut texturedQuadVertex(
        uint vid                     [[vertex_id]],
        constant Uniforms    &uniforms [[buffer(0)]],
        constant packed_float4 &rect   [[buffer(1)]]
    ) {
        float2 origin = float2(rect[0], rect[1]);
        float2 size   = float2(rect[2], rect[3]);

        float2 corners[6] = {
            float2(0,0), float2(1,0), float2(0,1),
            float2(1,0), float2(1,1), float2(0,1)
        };

        float2 pos = origin + corners[vid] * size;
        float2 clip = (pos / uniforms.viewportSize) * 2.0 - 1.0;

        // Flip V so that texture top matches quad top (AppKit Y-up)
        float2 uv = float2(corners[vid].x, 1.0 - corners[vid].y);

        TQVertexOut out;
        out.position = float4(clip, 0.0, 1.0);
        out.texCoord = uv;
        return out;
    }

    fragment float4 texturedQuadFragment(
        TQVertexOut in              [[stage_in]],
        texture2d<float> tex        [[texture(0)]]
    ) {
        constexpr sampler s(mag_filter::linear, min_filter::linear);
        float4 c = tex.sample(s, in.texCoord);
        // The bitmap is already composited; pass through.
        return c;
    }
    """
    // swiftlint:enable line_length
}

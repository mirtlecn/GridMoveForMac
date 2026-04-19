#include <metal_stdlib>
using namespace metal;

struct OverlayVertex {
    float2 position [[attribute(0)]];
    float2 uv       [[attribute(1)]];
};

struct OverlayRectParams {
    float4 fillColor;
    float4 strokeColor;
    float  strokeWidth;
    float  cornerRadius;
    float2 rectSize;
};

struct RasterizerData {
    float4 position [[position]];
    float2 uv;
};

vertex RasterizerData overlayVertexShader(
    OverlayVertex in [[stage_in]],
    constant float4x4 &projectionMatrix [[buffer(1)]]
) {
    RasterizerData out;
    out.position = projectionMatrix * float4(in.position, 0.0, 1.0);
    out.uv = in.uv;
    return out;
}

static float roundedRectSDF(float2 p, float2 halfSize, float radius) {
    float2 d = abs(p) - halfSize + float2(radius);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

fragment float4 overlayFragmentShader(
    RasterizerData in [[stage_in]],
    constant OverlayRectParams &params [[buffer(0)]]
) {
    float2 pixelPos = in.uv * params.rectSize;
    float2 center = params.rectSize * 0.5;
    float dist = roundedRectSDF(pixelPos - center, center, params.cornerRadius);

    if (dist > 0.5) {
        discard_fragment();
    }

    float fillAlpha = 1.0 - smoothstep(-0.5, 0.5, dist);
    float4 color = params.fillColor * fillAlpha;

    if (params.strokeWidth > 0.0) {
        float innerEdge = -params.strokeWidth;
        float strokeAlpha = smoothstep(innerEdge - 0.5, innerEdge + 0.5, dist);
        color = mix(color, float4(params.strokeColor.rgb, params.strokeColor.a * fillAlpha), strokeAlpha);
    }

    return color;
}

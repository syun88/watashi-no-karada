#include <metal_stdlib>
using namespace metal;

struct GaussianPoint {
    float4 position;
    float4 color;
};

struct Uniforms {
    float4x4 mvp;
    float pointSize;
    float3 pad;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float pointSize [[point_size]];
};

vertex VertexOut gaussianVertex(
    uint id [[vertex_id]],
    device const GaussianPoint *points [[buffer(0)]],
    constant Uniforms &u [[buffer(1)]]) {
    VertexOut out;
    out.position = u.mvp * points[id].position;
    out.color = points[id].color;
    out.pointSize = u.pointSize;
    return out;
}

fragment float4 gaussianFragment(VertexOut in [[stage_in]], float2 pointCoord [[point_coord]]) {
    float2 d = pointCoord - 0.5;
    float r2 = dot(d, d);
    float alpha = exp(-r2 * 18.0) * in.color.a;
    if (alpha < 0.02) discard_fragment();
    return float4(in.color.rgb, alpha);
}

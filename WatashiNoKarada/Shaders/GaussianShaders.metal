#include <metal_stdlib>
using namespace metal;

struct GaussianPoint {
    float4 position;
    float4 color;
    float sigmaM;
    float3 padding;
};

struct Uniforms {
    float4x4 mvp;
    // x = viewport height, y = projection Y scale, z = min point size, w = max point size
    float4 splatParams;
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
    float4 clip = u.mvp * points[id].position;
    out.position = clip;
    out.color = points[id].color;

    // Project a metric isotropic Gaussian sigma into screen space. This keeps splat size tied to
    // LiDAR geometry rather than using one fixed pixel radius for every depth.
    float clipW = max(fabs(clip.w), 0.001f);
    float projectedDiameterPx = points[id].sigmaM * u.splatParams.x * u.splatParams.y / clipW;
    out.pointSize = clamp(projectedDiameterPx, u.splatParams.z, u.splatParams.w);
    return out;
}

fragment float4 gaussianFragment(VertexOut in [[stage_in]], float2 pointCoord [[point_coord]]) {
    float2 d = pointCoord - 0.5f;
    float r2 = dot(d, d);
    // Isotropic 2D Gaussian footprint after perspective projection.
    float alpha = exp(-r2 * 18.0f) * in.color.a;
    if (alpha < 0.03f) discard_fragment();
    return float4(in.color.rgb, alpha);
}

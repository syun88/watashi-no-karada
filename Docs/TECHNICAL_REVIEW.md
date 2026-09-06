# Technical Review — 2026-09-06

This document records the technical review status of the current MVP. It intentionally separates what is already valid from what still requires real-device validation.

## Review result

### Correct / appropriate for the MVP

- **Metric source of truth:** ARKit Scene Depth is used for physical distance. Apple documents `depthMap` values as distance from the camera in meters and exposes `confidenceMap` for filtering.
- **Depth unprojection:** camera intrinsics are scaled to the depth-map resolution and used to convert pixels + depth into metric 3D points.
- **Self-scan interaction:** four stopped poses are safer than continuous human rotation for this MVP because the phone is fixed while the person moves and deforms.
- **Circumference math:** Ramanujan's second approximation is correctly implemented for an ellipse once left-right and anterior-posterior diameters are available.
- **Measurement / rendering separation:** body measurements come from LiDAR geometry, not from rendered splats.
- **Privacy architecture:** no network client is present in v0.1.0; scan archives stay in the app sandbox.

### Improved during this review

- Body extraction no longer relies only on every pixel inside one depth band. A center-seeded 8-connected component rejects disconnected background/furniture at similar depth.
- Row width uses the contiguous silhouette run nearest the torso center instead of the first and last accepted pixels across the whole row. This reduces arm/background inflation.
- Front/back and side measurements are confidence-weighted.
- Gaussian preview now stores an approximate **metric sigma** per point and projects splat size according to view depth instead of using one fixed pixel size.
- Documentation no longer calls the current renderer a complete optimized 3DGS radiance field.

## 3D Gaussian Splatting classification

The current renderer is best described as:

> **depth-initialized isotropic Gaussian splat surface preview**

It is a useful Gaussian-splat representation, but it is **not yet the full Kerbl et al. 3DGS pipeline**.

A full / conventional 3DGS pipeline normally includes a set of 3D Gaussians with optimized geometry/appearance parameters, anisotropic covariance, opacity, view-dependent color (commonly SH), density control, and visibility-aware alpha compositing. The original method optimizes these parameters from calibrated multi-view imagery.

The current app deliberately does not use a trained radiance field as the dimensional source of truth because:

1. the user moves while the camera is fixed;
2. the human body is non-rigid while turning;
3. four sparse views are not ideal for photorealistic 3DGS optimization;
4. LiDAR already provides metric depth, which is more appropriate for the measurement objective.

## Items that are not yet validated

### 1. Portrait orientation on the target iPhone

The code contains an explicit landscape-to-portrait depth mapping. It is internally consistent, but the exact orientation must be confirmed on the user's real device. If the first point cloud is rotated/mirrored, replace the hard-coded transform with an orientation-driven transform.

### 2. Anatomical measurement height

The current waist / abdomen / hip bands are silhouette-ratio based. This is the largest algorithmic limitation for absolute anatomical measurements. The next accuracy step should use Vision body landmarks and/or a user-defined reference band.

### 3. Four-view registration

Known quarter-turn yaw + recentering is sufficient for a progress preview, but it is not rigid ICP and it cannot compensate for posture/body deformation. Before using a merged cloud for direct circumference extraction, add registration and cross-section validation.

### 4. Absolute accuracy

No real-device tape-measure ground truth has been collected yet. Do not claim centimeter-grade accuracy until repeatability and bias are measured.

## Required first-device acceptance tests

1. Five scans without moving the phone: calculate standard deviation for each measurement.
2. Change distance by ±20 cm: verify the estimated circumference remains approximately stable.
3. Compare one scan with a real flexible tape at the exact same measurement site.
4. Inspect front/side silhouette bands to confirm they are on the intended body regions.
5. Confirm the splat cloud is upright, not mirrored, and all four views roughly overlap.
6. Check performance/thermal behavior during at least 10 consecutive scans.

## References

- Apple, ARKit Scene Depth / point cloud sample: https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth
- Apple, `ARDepthData`: https://developer.apple.com/documentation/arkit/ardepthdata
- Kerbl et al., *3D Gaussian Splatting for Real-Time Radiance Field Rendering*: https://arxiv.org/abs/2308.04079

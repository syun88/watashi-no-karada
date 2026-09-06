# Architecture

## Product goal

A private, mostly on-device body-progress recorder for a single user who does not have a measuring tape or a second person available to film them.

The app deliberately separates **metric geometry** from **visualization**:

- ARKit LiDAR Scene Depth is the dimensional source of truth.
- A depth-initialized Gaussian splat surface is used for fast 3D progress visualization.
- SwiftData stores small measurement records.
- Scan point clouds are stored as protected local JSON files.

## Scan flow

```text
Fixed iPhone (portrait)
        |
        v
ARWorldTrackingConfiguration
sceneDepth + smoothedSceneDepth
        |
        v
Portrait coordinate normalization
        |
        v
Central torso median depth
        |
        v
Confidence-filtered depth band
        |
        v
Center-seeded connected component
        |
        +----> front silhouette width
        +----> right-side silhouette depth
        +----> back silhouette width
        +----> left-side silhouette depth
        |
        v
Quality-weighted orthogonal diameters
        |
        v
Ellipse perimeter estimation
        |
        +----> waist-band
        +----> abdomen-band
        +----> hip-band
        |
        v
SwiftData BodyRecord
```

Each capture also generates a decimated metric body point cloud. Because the user rotates by known quarter-turns, each cloud is recentered and rotated back into a canonical body coordinate system before merging.

## Why four stopped poses instead of continuous rotation?

A stationary camera plus a moving human is not the standard rigid-scene assumption used by conventional multi-view reconstruction. A person also deforms while turning. Four guided stopped poses reduce motion artifacts and give the app an explicit known yaw transform for each view.

## Gaussian representation

`GaussianCloudView` + `GaussianShaders.metal` implement a **depth-initialized isotropic Gaussian splat preview**.

Current attributes per splat:

- metric XYZ mean from LiDAR
- metric isotropic sigma estimated from the depth-pixel footprint
- RGBA color/tint

The shader projects metric sigma into screen space according to view depth and uses a Gaussian alpha footprint.

This should **not** be described as a complete optimized photorealistic 3DGS radiance field. Current implementation does not yet contain:

- anisotropic 3D covariance optimization
- learned opacity / densification / pruning
- RGB multi-view training
- Spherical Harmonics
- full visibility-aware sorted alpha compositing

Measurements continue to come from metric LiDAR geometry even if the visual renderer becomes more advanced.

## Measurement model

The MVP estimates a cross section as an ellipse.

- front/back quality-weighted average = left-right diameter
- right/left quality-weighted average = anterior-posterior diameter
- circumference = Ramanujan second approximation

Before width extraction, the processor uses a center-seeded connected body component. Per-row width selects the contiguous run closest to the torso center, which reduces disconnected arms/furniture from inflating the measurement.

This model is intentionally simple and repeatability-first. A later version should locate anatomical levels with Vision landmarks and fit a cross-sectional curve from registered 3D points rather than assume an ellipse.

## On-device privacy

No network client is included in v0.1.0. Camera/depth data is processed in memory. Saved 3D data is written under Application Support with file protection.

## Validation boundary

The simulator build verifies code integration only. The following remain real-device validation items:

1. exact raw-to-portrait orientation on the target iPhone;
2. repeatability across five unchanged scans;
3. systematic bias against a flexible tape;
4. anatomical band placement;
5. four-view overlap and posture sensitivity;
6. thermal/performance behavior on device.

See `TECHNICAL_REVIEW.md` and `TEST_PLAN.md`.

# Architecture

## Product goal

A private, mostly on-device body-progress recorder for a single user who does not have a measuring tape or a second person available to film them.

The app deliberately separates **metric geometry** from **visualization**:

- ARKit LiDAR Scene Depth is the dimensional source of truth.
- Gaussian splats are used to preserve and visualize the 3D body surface.
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
Nearest coherent depth cluster
        |
        +----> front width
        +----> right-side depth
        +----> back width
        +----> left-side depth
        |
        v
Ellipse perimeter estimation
        |
        +----> waist
        +----> abdomen
        +----> hip
        |
        v
SwiftData BodyRecord
```

Each of the four captures also generates a decimated metric point cloud. Because the user rotates by known quarter-turns, each cloud is recentered and rotated back into a canonical body coordinate system before merging.

## Why four stopped poses instead of continuous rotation?

A stationary camera plus a moving human is not the standard rigid-scene assumption used by conventional 3D reconstruction or COLMAP-based 3DGS pipelines. A person also deforms while turning. Four guided stopped poses reduce motion artifacts and give the app an explicit known yaw transform for each view.

## Gaussian representation

`GaussianCloudView` uses Metal point primitives with a Gaussian alpha falloff in `GaussianShaders.metal`.

Current attributes per splat:

- metric XYZ mean
- RGBA color/tint
- fixed screen-space sigma

Future optimizer slots:

- local covariance / anisotropic scale
- per-splat opacity
- RGB reprojection from camera frames
- SH coefficients
- view-dependent optimization

Measurements must continue to come from metric LiDAR geometry even if the visual renderer becomes photorealistic.

## Measurement model

The MVP estimates a cross section as an ellipse.

- front/back average = left-right diameter
- right/left average = anterior-posterior diameter
- circumference = Ramanujan second approximation

This model is intentionally simple and reproducible. Later versions should fit a concave cross-sectional curve from registered 3D points rather than assume an ellipse.

## On-device privacy

No network client is included in v0.1.0. Camera/depth data is processed in memory. Saved 3D data is written under Application Support with complete file protection.

## High-priority validation after first device install

1. Check raw-to-portrait depth orientation on the user's exact iPhone model.
2. Verify the full body fits inside the depth silhouette at 1.8–2.4 m.
3. Measure the same pose 5 times and inspect repeatability before trusting absolute accuracy.
4. Compare against a real tape once available to estimate systematic bias.
5. Inspect side-view depth clustering around arms and loose clothing.
6. Tune waist/abdomen/hip vertical ratios or replace them with Vision landmarks.

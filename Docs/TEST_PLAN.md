# First-device test plan

## A. Install sanity

- Open `WatashiNoKarada.xcodeproj`.
- Select a Development Team.
- Run on a LiDAR iPhone, not Simulator.
- Grant camera access.
- Confirm the Scan tab reports no LiDAR-support error.

## B. One-person scan usability

Use a stable support so the rear camera faces the user.

- Distance: start around 2.0 m.
- Pose: feet stable, arms slightly away from torso.
- Clothing: thin and not loose.
- Keep the same breathing state for all four directions.
- Follow Japanese voice guidance through front/right/back/left.

Expected result: four captures complete without another person touching the phone.

## C. Repeatability before accuracy

Run 5 scans without changing clothes or setup.

Record:

- waist estimate
- abdomen estimate
- hip estimate
- quality score
- reported distance

The most important first metric is the standard deviation of repeated scans. A consistent offset can be calibrated later; high random variance must be fixed first.

## D. Visual check

Open the stored scan detail.

Expected:

- splat cloud is upright rather than rotated 90°
- four surfaces roughly form one body volume
- body does not appear four times around the origin
- the cloud rotates smoothly on device

## E. Known MVP limitations

- anatomical levels are ratio-based, not yet landmark-based
- loose clothes and arms near the waist can widen the silhouette
- four views use known yaw, not ICP/non-rigid registration
- splats are metric depth-derived Gaussian visualization, not full optimized photorealistic 3DGS training

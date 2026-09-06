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

## C. Orientation / segmentation sanity

Before trusting any number, confirm:

- the depth body silhouette is upright in portrait;
- the selected body component follows the user rather than a wall/chair;
- detached arms are not included in the torso width run at the measurement band;
- reported distance is close to the actual phone-to-body distance.

## D. Repeatability before accuracy

Run 5 scans without changing clothes, phone position or pose protocol.

Record:

- waist estimate
- abdomen estimate
- hip estimate
- quality score
- reported distance

Calculate mean, standard deviation and max-min range. The first acceptance criterion is **low random variance**. A consistent offset can be calibrated later; unstable variance must be fixed first.

## E. Distance invariance

Repeat a scan at approximately 1.8 m, 2.0 m and 2.2 m while keeping pose and clothing unchanged.

Expected: circumference should not scale proportionally with camera distance. Large drift indicates an intrinsics/orientation/segmentation bug.

## F. Ground-truth check

When a flexible tape becomes available, compare the app with a tape at the **exact same body band and breathing state**. Repeat three times. Record systematic bias instead of calibrating from a single measurement.

## G. 3D visual check

Open the stored scan detail.

Expected:

- splat surface is upright rather than rotated 90°;
- four surfaces roughly form one body volume;
- body does not appear four times around the origin;
- splat size changes naturally with view depth;
- the cloud rotates smoothly on device.

## H. Performance / privacy

- Run 10 scans in sequence and watch for memory pressure or thermal throttling.
- Confirm Airplane Mode does not change core functionality.
- Confirm no network permission/API is required for scanning, history or 3D preview.

## Known MVP limitations

- measurement levels are ratio-based, not yet landmark-based;
- loose clothes and arms touching the torso can still change the silhouette;
- four views use known yaw + recentering, not ICP/non-rigid registration;
- the renderer is a depth-initialized isotropic Gaussian splat preview, not a fully optimized photorealistic 3DGS radiance field;
- absolute centimeter accuracy is not claimed until real-device validation is complete.

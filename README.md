# わたしのカラダ — On-device LiDAR Body Progress Tracker

> メジャーや第三者撮影に頼らず、iPhone LiDARで「体の変化」を同じ条件で記録するためのダイエット / 筋トレ記録アプリ。

![UI concept](Docs/ui-concept.svg)

## MVPでできること

- iPhoneを固定し、**正面 → 右 → 背面 → 左**を音声ガイドでセルフスキャン
- ARKit `sceneDepth` / `smoothedSceneDepth` を使ったオンデバイス深度取得
- LiDARの実距離からウエスト・お腹・ヒップを推定
- 4方向の人体表面点を既知の90°回転で人体座標へ寄せて統合
- 深度点を **Gaussian splat cloud** としてMetalで端末内描画
- SwiftDataで計測履歴を端末内保存
- Swift Chartsでウエスト推移を表示
- 手入力の体重 / ウエスト / メモも同じ履歴に記録
- スキャンJSONはApplication Support以下にファイル保護付きで保存
- クラウド送信なし（v0.1.0）

## デザイン

- [UI design board](Docs/ui-concept.svg)
- [App icon source](Docs/app-icon-source.svg)
- iPhone用AppIcon PNG一式は `WatashiNoKarada/Resources/Assets.xcassets/AppIcon.appiconset/` に収録

## 重要: 3D Gaussian Splattingについて

このMVPは、LiDAR由来の各3D点をGaussian meanとして描画する**metric depth-derived Gaussian splat representation**です。体寸法は3DGSの見た目からではなくLiDAR geometryから計算します。

一般的な写真ベース3DGSのような、学習ループ・Spherical Harmonics・opacity/scale最適化によるphotorealistic radiance-field trainingはまだ入れていません。理由は、初期版で「毎日使える速度」「オンデバイス」「寸法のメートル基準」を優先するためです。`GaussianCloudView` と `.metal` shaderを独立させてあり、後からMetal computeによるscale/opacity/color最適化を追加できます。

## 測定アルゴリズム

1. LiDAR depthの中央領域から最も近い有意なdepth clusterを人体候補として抽出
2. depth confidenceが低い点を除外
3. 深度シルエットから標準化された腰 / 腹部 / ヒップ高さの横幅を取得
4. 正面+背面の平均を左右径、右+左の平均を前後径とする
5. 楕円断面とみなし、Ramanujan近似で周長を算出
6. 各poseの点群を重心中心化し、既知の0/90/180/270°でcanonicalizeして3D記録

この方式は絶対値の医療計測ではなく、**同一人物の時系列変化**を安定して追うことを目的にしています。

## 推奨撮影条件

- LiDAR搭載iPhone Pro / Pro Max
- 背面カメラを自分へ向けて固定
- 約1.8〜2.4 m離れる
- 腕を体から少し離す
- 薄手で毎回似た服装
- 普通に息を吐いた状態で姿勢を揃える
- 背景との距離差がある場所で撮る

## 開発環境

- iOS 17+
- SwiftUI
- SwiftData
- ARKit / LiDAR Scene Depth
- Metal / MetalKit
- Swift Charts
- AVFoundation (Japanese voice guide)

## 実行

1. `WatashiNoKarada.xcodeproj` をXcodeで開く
2. Signing & Capabilitiesで自分のDevelopment Teamを選ぶ
3. LiDAR搭載の実機を接続する
4. `WatashiNoKarada` schemeをRun
5. カメラ権限を許可して「スキャン」から開始

SimulatorではLiDAR計測は動きません。

## Docs

- [Architecture](Docs/ARCHITECTURE.md)
- [First-device test plan](Docs/TEST_PLAN.md)

## Privacy

v0.1.0ではネットワークAPIを使用しません。深度・寸法・3D記録はアプリのsandbox内に保存します。

## Roadmap

- Vision 2D/3D body poseを用いた腰高さの自動ランドマーク補正
- 4-view ICP / non-rigid registration
- Gaussian scale/opacityのon-device optimization
- RGB色をGaussianへ投影
- Before / After 3D差分 heatmap
- Apple Watchからスキャン開始・音声/触覚ガイド
- HealthKit（体重）の任意連携
- 撮影条件の再現性スコア

## Credits

Concept / Product direction: **SYUN**  
Initial implementation & design collaboration: **SYUN × OpenAI**

## License

MIT

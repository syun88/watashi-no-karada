import SwiftUI

struct ScanResultView: View {
    let archive: ScanArchive
    let onDone: () -> Void
    @State private var show3D = true

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44)).foregroundStyle(Color.appTeal)
                    Text("スキャン完了").font(.title2.bold())
                    Text("端末内で4方向の深度を統合しました")
                        .font(.caption).foregroundStyle(.secondary)
                }

                GaussianCloudView(points: archive.mergedPoints)
                    .frame(height: 330)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(alignment: .topTrailing) {
                        Label("On-device splats", systemImage: "cpu")
                            .font(.caption2.bold())
                            .padding(8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(10)
                    }

                HStack(spacing: 10) {
                    MetricCard(title: "ウエスト", value: String(format: "%.1f cm", archive.waistCM), footnote: nil, systemImage: "ruler")
                    MetricCard(title: "お腹", value: String(format: "%.1f cm", archive.abdomenCM), footnote: nil, systemImage: "figure")
                }
                MetricCard(title: "ヒップ", value: String(format: "%.1f cm", archive.hipCM), footnote: String(format: "品質 %.0f%%", archive.qualityScore * 100), systemImage: "figure.stand")

                VStack(alignment: .leading, spacing: 8) {
                    Label("この数値について", systemImage: "info.circle")
                        .font(.headline)
                    Text("LiDARの実距離を基準に、正面/背面の幅と左右側面の厚みを楕円断面として統合した推定値です。毎回同じ条件で測ることで、絶対値よりも変化量の追跡に強くなります。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))

                Button(action: onDone) {
                    Text("保存してホームへ")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(LinearGradient(colors: [.appBlue, .appTeal], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle("スキャン結果")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled()
    }
}

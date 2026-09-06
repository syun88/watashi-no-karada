import SwiftUI

struct ScanLandingView: View {
    @State private var showScanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.appBlue.opacity(0.14), .appTeal.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 190, height: 190)
                    Image(systemName: "viewfinder.circle.fill")
                        .font(.system(size: 88))
                        .foregroundStyle(LinearGradient(colors: [.appBlue, .appTeal], startPoint: .top, endPoint: .bottom))
                }

                VStack(spacing: 8) {
                    Text("ひとりで4方向スキャン")
                        .font(.title2.bold())
                    Text("iPhoneを固定して、音声案内に合わせて90°ずつ回るだけ。LiDARから腰・お腹・ヒップの変化を記録します。")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    instruction("1", "iPhoneを固定", "背面カメラを体に向け、約1.8〜2.4m離します。")
                    instruction("2", "腕を少し開く", "体の輪郭が分かる薄手の服がおすすめです。")
                    instruction("3", "正面から開始", "正面 → 右 → 背面 → 左を自動で撮影します。")
                }

                Button {
                    showScanner = true
                } label: {
                    Label("ボディスキャンを開始", systemImage: "viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(LinearGradient(colors: [.appBlue, .appTeal], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle("スキャン")
        .fullScreenCover(isPresented: $showScanner) {
            GuidedScanView(isPresented: $showScanner)
        }
    }

    private func instruction(_ number: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.appBlue, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }
}

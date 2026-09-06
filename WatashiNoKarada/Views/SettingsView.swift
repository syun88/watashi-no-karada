import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("プライバシー") {
                Label("スキャン処理はオンデバイス", systemImage: "iphone.gen3")
                Label("3Dデータはアプリ領域に保存", systemImage: "lock.fill")
                Text("この初期版はクラウド送信を行いません。LiDAR深度からの計測と3DプレビューはiPhone内で処理します。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("測定について") {
                Text("同じ距離・姿勢・服装・呼吸状態で測るほど、日ごとの比較が安定します。数値は健康・ダイエット記録向けの推定値で、医療用途ではありません。")
                    .font(.footnote)
            }
            Section("推奨") {
                Label("iPhone Pro / Pro Max（LiDAR搭載）", systemImage: "sensor.tag.radiowaves.forward")
                Label("約1.8〜2.4m離して固定", systemImage: "arrow.left.and.right")
                Label("腕を少し開き、薄手の服で測定", systemImage: "figure.stand")
            }
            Section {
                HStack { Text("Version"); Spacer(); Text("0.1.0 MVP").foregroundStyle(.secondary) }
                HStack { Text("Design & concept"); Spacer(); Text("syun × OpenAI").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("設定")
    }
}

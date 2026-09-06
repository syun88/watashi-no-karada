import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selection: AppRootView.Tab
    @Query(sort: \BodyRecord.date, order: .reverse) private var records: [BodyRecord]

    private var latest: BodyRecord? { records.first }
    private var previous: BodyRecord? { records.dropFirst().first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                waistHero
                metrics
                progressCard
                quickActions
            }
            .padding()
        }
        .navigationTitle("わたしのカラダ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今日も、記録をひとつずつ。")
                .font(.title2.bold())
            Text("スキャン・体重・変化を端末の中で管理します。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var waistHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("最新のウエスト", systemImage: "ruler")
                .font(.headline)
            Text(latest.map { String(format: "%.1f cm", $0.waistCM) } ?? "未記録")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
            if let latest, let previous {
                let diff = latest.waistCM - previous.waistCM
                Text(String(format: "前回比 %+.1f cm", diff))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(diff <= 0 ? .appTeal : .orange)
            } else {
                Text("最初のLiDARスキャンを記録しましょう")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(colors: [.appBlue.opacity(0.14), .appTeal.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            MetricCard(title: "体重", value: latest?.weightKG.map { String(format: "%.1f kg", $0) } ?? "—", footnote: nil, systemImage: "scalemass")
            MetricCard(title: "記録", value: "\(records.count)回", footnote: records.isEmpty ? nil : "端末内保存", systemImage: "calendar")
        }
    }

    private var progressCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Color.appTeal)
            VStack(alignment: .leading, spacing: 4) {
                Text("見た目だけでなく、同じ条件で比較")
                    .font(.headline)
                Text("毎回4方向から測ることで、メジャーなしでも変化を追いやすくします。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("クイックアクション").font(.headline)
            HStack(spacing: 10) {
                Button { selection = .scan } label: { action("スキャン開始", "viewfinder", .appBlue) }
                Button { selection = .record } label: { action("記録する", "square.and.pencil", .appTeal) }
                Button { selection = .analysis } label: { action("履歴を見る", "chart.line.uptrend.xyaxis", .appBlue.opacity(0.8)) }
            }
            .buttonStyle(.plain)
        }
    }

    private func action(_ title: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2)
            Text(title).font(.caption.bold()).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

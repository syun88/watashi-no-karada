import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @Query(sort: \BodyRecord.date) private var records: [BodyRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if records.isEmpty {
                    ContentUnavailableView("まだ履歴がありません", systemImage: "chart.xyaxis.line", description: Text("最初のスキャンまたは手入力を保存すると、ここに変化が表示されます。"))
                        .frame(minHeight: 360)
                } else {
                    waistChart
                    if records.count >= 2 {
                        let pair = Array(records.suffix(2))
                        NavigationLink {
                            ScanComparisonView(older: pair[0], newer: pair[1])
                        } label: {
                            HStack {
                                Image(systemName: "square.split.2x1")
                                Text("最新2件をBefore / After比較")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline.bold())
                            .padding()
                            .foregroundStyle(.white)
                            .background(LinearGradient(colors: [.appBlue, .appTeal], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    history
                }
            }
            .padding()
        }
        .navigationTitle("履歴・分析")
    }

    private var waistChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ウエストの変化").font(.headline)
            Chart(records) { record in
                LineMark(x: .value("日付", record.date), y: .value("cm", record.waistCM))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("日付", record.date), y: .value("cm", record.waistCM))
            }
            .chartYAxisLabel("cm")
            .frame(height: 240)
        }
        .padding()
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("記録一覧").font(.headline)
            ForEach(records.reversed()) { record in
                NavigationLink {
                    RecordDetailView(record: record)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.bold())
                            Text(String(format: "ウエスト %.1f cm", record.waistCM)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let weight = record.weightKG { Text(String(format: "%.1f kg", weight)).font(.caption).foregroundStyle(.secondary) }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

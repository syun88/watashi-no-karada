import SwiftUI

struct ScanComparisonView: View {
    let older: BodyRecord
    let newer: BodyRecord
    @State private var selected = 1
    @State private var olderArchive: ScanArchive?
    @State private var newerArchive: ScanArchive?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("表示", selection: $selected) {
                    Text("前回").tag(0)
                    Text("今回").tag(1)
                }
                .pickerStyle(.segmented)

                if let archive = selected == 0 ? olderArchive : newerArchive {
                    GaussianCloudView(points: archive.mergedPoints)
                        .frame(height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                } else {
                    ContentUnavailableView("3Dデータなし", systemImage: "cube.transparent", description: Text("手入力の記録など、3Dスキャンが保存されていない記録です。"))
                        .frame(height: 260)
                }

                HStack(spacing: 10) {
                    compareCard("ウエスト", older.waistCM, newer.waistCM)
                    if let a = older.abdomenCM, let b = newer.abdomenCM {
                        compareCard("お腹", a, b)
                    }
                }
                if let a = older.hipCM, let b = newer.hipCM {
                    compareCard("ヒップ", a, b)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("比較期間").font(.headline)
                    HStack {
                        Text(older.date.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Image(systemName: "arrow.right")
                        Spacer()
                        Text(newer.date.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding()
        }
        .navigationTitle("Before / After")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
    }

    private func compareCard(_ title: String, _ old: Double, _ new: Double) -> some View {
        let diff = new - old
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(String(format: "%.1f cm", new)).font(.title3.bold()).monospacedDigit()
            Text(String(format: "%+.1f cm", diff))
                .font(.caption.bold())
                .foregroundStyle(diff <= 0 ? Color.appTeal : Color.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.12)))
    }

    private func load() {
        if let file = older.scanFileName { olderArchive = try? ScanArchiveStore.shared.load(fileName: file) }
        if let file = newer.scanFileName { newerArchive = try? ScanArchiveStore.shared.load(fileName: file) }
    }
}

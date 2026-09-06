import SwiftUI

struct RecordDetailView: View {
    let record: BodyRecord
    @State private var archive: ScanArchive?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let archive {
                    GaussianCloudView(points: archive.mergedPoints)
                        .frame(height: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }

                HStack(spacing: 10) {
                    MetricCard(title: "ウエスト", value: String(format: "%.1f cm", record.waistCM), footnote: nil, systemImage: "ruler")
                    MetricCard(title: "体重", value: record.weightKG.map { String(format: "%.1f kg", $0) } ?? "—", footnote: nil, systemImage: "scalemass")
                }
                if let abdomen = record.abdomenCM, let hip = record.hipCM {
                    HStack(spacing: 10) {
                        MetricCard(title: "お腹", value: String(format: "%.1f cm", abdomen), footnote: nil, systemImage: "figure")
                        MetricCard(title: "ヒップ", value: String(format: "%.1f cm", hip), footnote: nil, systemImage: "figure.stand")
                    }
                }

                if !record.note.isEmpty {
                    Text(record.note)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .navigationTitle(record.date.formatted(date: .abbreviated, time: .omitted))
        .onAppear {
            if let fileName = record.scanFileName {
                archive = try? ScanArchiveStore.shared.load(fileName: fileName)
            }
        }
    }
}

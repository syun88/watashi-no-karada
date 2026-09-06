import SwiftUI
import SwiftData

struct GuidedScanView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var context
    @StateObject private var controller = ScanSessionController()
    @State private var result: ScanMeasurement?
    @State private var archive: ScanArchive?
    @State private var errorText: String?

    var body: some View {
        ZStack {
            ARSessionPreview(session: controller.session)
                .ignoresSafeArea()

            LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.58)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                scanOverlay
                Spacer()
                bottomCard
            }
            .padding(.horizontal)
            .padding(.bottom, 18)
        }
        .onAppear { controller.startSession() }
        .onDisappear { controller.stopSession() }
        .onChange(of: controller.state) { _, newValue in
            if newValue == .complete { finishProcessing() }
            if case .failed(let message) = newValue { errorText = message }
        }
        .sheet(item: $archive) { archive in
            NavigationStack {
                ScanResultView(archive: archive, onDone: {
                    isPresented = false
                })
            }
        }
        .alert("スキャンできませんでした", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("再試行") { errorText = nil; controller.beginGuidedScan() }
            Button("閉じる", role: .cancel) { isPresented = false }
        } message: {
            Text(errorText ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            Button { isPresented = false } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.38), in: Circle())
            }
            Spacer()
            Text("ボディスキャン")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
        .padding(.top, 10)
    }

    private var scanOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 7]))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 220, height: 430)
            VStack(spacing: 6) {
                Text(controller.currentPose.title)
                    .font(.title.bold())
                Text(statusText)
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.black.opacity(0.38), in: Capsule())
        }
    }

    private var bottomCard: some View {
        VStack(spacing: 14) {
            ProgressView(value: controller.progress)
                .tint(.appTeal)
            HStack {
                Label("\(controller.captures.count) / 4", systemImage: "circle.grid.2x2.fill")
                Spacer()
                if controller.latestDistanceM > 0 {
                    Text(String(format: "距離 %.1f m", controller.latestDistanceM))
                }
            }
            .font(.caption.bold())

            if controller.state == .idle {
                Button("準備OK・開始") { controller.beginGuidedScan() }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(.appBlue, in: RoundedRectangle(cornerRadius: 16))
            } else if case .failed = controller.state {
                Button("再試行") { controller.beginGuidedScan() }
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(.appBlue)
                    Text("音声に合わせてゆっくり向きを変えてください")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var statusText: String {
        switch controller.state {
        case .idle: return "枠の中央に全身を合わせます"
        case .preparing: return "姿勢を整えてください"
        case .countingDown(let n): return "\(n) 秒後に撮影"
        case .capturing: return "LiDAR深度を取得中…"
        case .complete: return "スキャン完了"
        case .failed: return "再試行してください"
        }
    }

    private func finishProcessing() {
        guard let measurement = MeasurementEngine().measurement(from: controller.captures) else {
            errorText = "4方向の計測結果を統合できませんでした。"
            return
        }
        result = measurement
        let merged = controller.captures.flatMap(\.points)
        let newArchive = ScanArchive(
            version: 1,
            id: UUID(),
            createdAt: .now,
            waistCM: measurement.waistCM,
            abdomenCM: measurement.abdomenCM,
            hipCM: measurement.hipCM,
            qualityScore: measurement.qualityScore,
            captures: controller.captures,
            mergedPoints: merged
        )

        do {
            let fileName = try ScanArchiveStore.shared.save(newArchive)
            let record = BodyRecord(
                date: newArchive.createdAt,
                waistCM: measurement.waistCM,
                abdomenCM: measurement.abdomenCM,
                hipCM: measurement.hipCM,
                scanFileName: fileName,
                qualityScore: measurement.qualityScore,
                source: "lidar"
            )
            context.insert(record)
            try context.save()
            archive = newArchive
        } catch {
            errorText = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

extension ScanArchive: Identifiable {}

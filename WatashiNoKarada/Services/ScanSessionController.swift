import ARKit
import AVFoundation
import Combine
import Foundation
import UIKit

final class ScanSessionController: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case countingDown(Int)
        case capturing(PoseCapture.Pose)
        case complete
        case failed(String)
    }

    let session = ARSession()
    @Published var state: State = .idle
    @Published var currentPose: PoseCapture.Pose = .front
    @Published var captures: [PoseCapture] = []
    @Published var progress: Double = 0
    @Published var latestDistanceM: Float = 0
    @Published var isLiDARSupported = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)

    private let processor = BodyDepthProcessor()
    private let voice = VoiceGuide()
    private var workItem: DispatchWorkItem?

    override init() {
        super.init()
        session.delegate = self
    }

    func startSession() {
        guard isLiDARSupported else {
            state = .failed("このiPhoneはLiDAR Scene Depthに対応していません。")
            return
        }
        let config = ARWorldTrackingConfiguration()
        var semantics: ARConfiguration.FrameSemantics = [.sceneDepth]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            semantics.insert(.smoothedSceneDepth)
        }
        config.frameSemantics = semantics
        config.worldAlignment = .gravity
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stopSession() {
        workItem?.cancel()
        session.pause()
    }

    func beginGuidedScan() {
        captures.removeAll()
        progress = 0
        state = .preparing
        voice.speak("iPhoneを固定しましたら、画面中央に立ってください。腕は少し体から離します。")
        schedulePose(.front, delay: 4.0)
    }

    func cancel() {
        workItem?.cancel()
        captures.removeAll()
        progress = 0
        state = .idle
    }

    private func schedulePose(_ pose: PoseCapture.Pose, delay: TimeInterval) {
        currentPose = pose
        let instruction: String
        switch pose {
        case .front: instruction = "正面を向いてください。"
        case .right: instruction = "ゆっくり右に90度回って、右側をカメラに向けてください。"
        case .back: instruction = "もう90度回って、背中をカメラに向けてください。"
        case .left: instruction = "もう90度回って、左側をカメラに向けてください。"
        }
        voice.speak(instruction)
        runCountdown(after: delay, pose: pose, count: 3)
    }

    private func runCountdown(after delay: TimeInterval, pose: PoseCapture.Pose, count: Int) {
        let item = DispatchWorkItem { [weak self] in
            self?.countDown(pose: pose, value: count)
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func countDown(pose: PoseCapture.Pose, value: Int) {
        guard value > 0 else {
            capture(pose: pose)
            return
        }
        state = .countingDown(value)
        voice.speak("\(value)")
        let item = DispatchWorkItem { [weak self] in self?.countDown(pose: pose, value: value - 1) }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    private func capture(pose: PoseCapture.Pose) {
        state = .capturing(pose)
        guard let frame = session.currentFrame else {
            state = .failed("カメラフレームを取得できませんでした。")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.processor.process(frame: frame, pose: pose)
            DispatchQueue.main.async {
                guard let result else {
                    self.state = .failed("人体の深度を安定して取得できませんでした。距離と照明を確認して再試行してください。")
                    return
                }
                self.captures.append(result.pose)
                self.latestDistanceM = result.pose.distanceM
                self.progress = Double(self.captures.count) / 4.0
                if let next = PoseCapture.Pose(rawValue: pose.rawValue + 1) {
                    self.schedulePose(next, delay: 2.5)
                } else {
                    self.state = .complete
                    self.voice.speak("スキャンが完了しました。お疲れさまでした。")
                }
            }
        }
    }
}

extension ScanSessionController: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.state = .failed(error.localizedDescription) }
    }
}

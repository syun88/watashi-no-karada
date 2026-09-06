import SwiftUI
import MetalKit
import QuartzCore
import simd

struct GaussianCloudView: UIViewRepresentable {
    let points: [CodablePoint]

    func makeCoordinator() -> Coordinator { Coordinator(points: points) }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.clearColor = MTLClearColor(red: 0.025, green: 0.055, blue: 0.12, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.preferredFramesPerSecond = 60
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.update(points: points)
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        struct GPUPoint {
            var position: SIMD4<Float>
            var color: SIMD4<Float>
        }

        struct Uniforms {
            var mvp: simd_float4x4
            var pointSize: Float
            var pad: SIMD3<Float> = .zero
        }

        private var device: MTLDevice?
        private var queue: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?
        private var depthState: MTLDepthStencilState?
        private var pointBuffer: MTLBuffer?
        private var pointCount = 0
        private var start = CACurrentMediaTime()
        private var source: [CodablePoint]

        init(points: [CodablePoint]) { self.source = points }

        func attach(to view: MTKView) {
            guard let device = view.device else { return }
            self.device = device
            self.queue = device.makeCommandQueue()
            let library = device.makeDefaultLibrary()
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library?.makeFunction(name: "gaussianVertex")
            descriptor.fragmentFunction = library?.makeFunction(name: "gaussianFragment")
            descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
            pipeline = try? device.makeRenderPipelineState(descriptor: descriptor)

            let depth = MTLDepthStencilDescriptor()
            depth.isDepthWriteEnabled = false
            depth.depthCompareFunction = .lessEqual
            depthState = device.makeDepthStencilState(descriptor: depth)
            view.delegate = self
            rebuildBuffer()
        }

        func update(points: [CodablePoint]) {
            guard points != source else { return }
            source = points
            rebuildBuffer()
        }

        private func rebuildBuffer() {
            guard let device else { return }
            // Keep the preview light enough for older LiDAR iPhones.
            let step = max(1, source.count / 28000)
            let gpu: [GPUPoint] = stride(from: 0, to: source.count, by: step).map { idx in
                let p = source[idx]
                return GPUPoint(position: SIMD4(p.x, p.y, p.z, 1), color: p.color)
            }
            pointCount = gpu.count
            if gpu.isEmpty {
                pointBuffer = nil
            } else {
                pointBuffer = device.makeBuffer(bytes: gpu, length: gpu.count * MemoryLayout<GPUPoint>.stride, options: .storageModeShared)
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard pointCount > 0,
                  let drawable = view.currentDrawable,
                  let pass = view.currentRenderPassDescriptor,
                  let queue,
                  let pipeline,
                  let pointBuffer,
                  let command = queue.makeCommandBuffer(),
                  let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }

            let t = Float(CACurrentMediaTime() - start)
            let aspect = Float(view.drawableSize.width / max(view.drawableSize.height, 1))
            let projection = Self.perspective(fovy: 55 * .pi / 180, aspect: aspect, near: 0.01, far: 20)
            let viewM = Self.translation(SIMD3(0, -0.05, -2.15))
            let rotation = Self.rotationY(t * 0.20)
            let model = Self.scale(1.55)
            var uniforms = Uniforms(mvp: projection * viewM * rotation * model, pointSize: 6.5)

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setVertexBuffer(pointBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: pointCount)
            encoder.endEncoding()
            command.present(drawable)
            command.commit()
        }

        private static func perspective(fovy: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
            let y = 1 / tan(fovy * 0.5)
            let x = y / max(aspect, 0.01)
            let z = far / (near - far)
            return simd_float4x4(
                SIMD4(x, 0, 0, 0),
                SIMD4(0, y, 0, 0),
                SIMD4(0, 0, z, -1),
                SIMD4(0, 0, z * near, 0)
            )
        }

        private static func translation(_ t: SIMD3<Float>) -> simd_float4x4 {
            simd_float4x4(
                SIMD4(1,0,0,0), SIMD4(0,1,0,0), SIMD4(0,0,1,0), SIMD4(t.x,t.y,t.z,1)
            )
        }

        private static func scale(_ s: Float) -> simd_float4x4 {
            simd_float4x4(diagonal: SIMD4(s,s,s,1))
        }

        private static func rotationY(_ a: Float) -> simd_float4x4 {
            let c = cos(a), s = sin(a)
            return simd_float4x4(
                SIMD4(c,0,-s,0), SIMD4(0,1,0,0), SIMD4(s,0,c,0), SIMD4(0,0,0,1)
            )
        }
    }
}

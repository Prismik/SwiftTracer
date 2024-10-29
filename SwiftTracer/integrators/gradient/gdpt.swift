//
//  gdpt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-07.
//

import Foundation
import Progress

/// Gradient domain metropolis light transport integrator
final class GdptIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case shiftMapping
        case reconstruction
        case maxDepth
        case minDepth
    }
    
    private let maxDepth: Int
    private let minDepth: Int
    private let mapper: ShiftMapping
    private let reconstructor: Reconstructing
    private var successfulShifts: Int = 0
    private var failedShifts: Int = 0

    private let gradientOffsets: [Vec2] = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]
    init(mapper: ShiftMapping, reconstructor: Reconstructing, maxReconstructIterations: Int, minDepth: Int = 0, maxDepth: Int = 16) {
        self.mapper = mapper
        self.reconstructor = reconstructor
        self.minDepth = minDepth
        self.maxDepth = maxDepth
    }

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let result: GradientDomainResult = render(scene: scene, sampler: sampler)
        return result.img
    }
}

// MARK:  Gradient tracing

extension GdptIntegrator: SamplerIntegrator {
    enum RayState {
        struct Data {
            var pdf: Float
            var ray: Ray
            var its: Intersection
            var throughput: Color
        }

        case fresh(data: Data)
        case connected(data: Data)
        case connectedRecently(data: Data)
        case dead
        
        func sanitized() -> RayState {
            return switch self {
            case .dead: .dead
            case .fresh(let e):
                Frame(n: e.its.n).toLocal(v: -e.ray.d).z <= 0 ? .dead : .fresh(data: e)
            case .connectedRecently(let e):
                e.its.n.dot(e.ray.d) > 0 ? .dead : .connectedRecently(data: e)
            case .connected(let e): .connected(data: e)
            }
        }
        
        static func new(pixel: Vec2, offset: Vec2, scene: Scene) -> RayState {
            let pixel = pixel + offset
            let max = scene.camera.resolution
            guard (0 ..< max.x).contains(pixel.x) && (0 ..< max.y).contains(pixel.y) else {
                return .dead
            }
            
            let ray = scene.camera.createRay(from: pixel)
            guard let its = scene.hit(r: ray) else { return .dead }
            return .fresh(data: Data(pdf: 1, ray: ray, its: its, throughput: Color(repeating: 1)))
        }
    }

    struct GradientColors {
        var main: Color
        var radiances: [Color]
        var gradients: [Color]
        
        init() {
            main = .zero
            radiances = Array(repeating: .zero, count: 4)
            gradients = Array(repeating: .zero, count: 4)
        }
    }

    func preprocess(scene: Scene, sampler: any Sampler) {
        // no op
    }

    private func newTrace(pixel: Vec2, scene: Scene) -> GradientColors {
        var li = GradientColors()
        guard var main: RayState.Data = switch RayState.new(pixel: pixel, offset: .zero, scene: scene) {
            case .dead: nil
            case .connected(let data), .connectedRecently(let data), .fresh(let data): data
        } else {
            return li
        }
        
        var offsets = gradientOffsets.map { RayState.new(pixel: pixel, offset: $0, scene: scene) }
        
        var depth = 1
        while depth <= self.maxDepth && depth >= self.minDepth {
            offsets = offsets.map { $0.sanitized() }

            if main.its.hasEmission && depth == 1 {
                let frame = Frame(n: main.its.n)
                let wo = frame.toLocal(v: -main.ray.d)
                li.main += main.its.shape.light.L(p: main.its.p, n: main.its.n, uv: main.its.uv, wo: wo)
                // TODO Should we return early here
            } else if !main.its.hasEmission && main.its.shape.material.hasDelta(uv: main.its.uv, p: main.its.p) == false {
                // Light sampling
                let rngLight = scene.sampler.next2()
                let lightSample: LightSample?
                let mainBsdfEval: Color
                let mainBsdfPdf: Float
                let mainFrame = Frame(n: main.its.n)
                let mainLightOutLocal: Vec3
                
                if let sample = scene.sample(context: LightSample.Context(p: main.its.p, n: main.its.n, ns: main.its.n), s: rngLight) {
                    lightSample = sample
                    mainLightOutLocal = mainFrame.toLocal(v: sample.wi)
                    let mainLightInLocal = mainFrame.toLocal(v: -main.ray.d)
                    mainBsdfEval = main.its.shape.material.evaluate(wo: mainLightInLocal, wi: mainLightOutLocal, uv: main.its.uv, p: main.its.p)
                    mainBsdfPdf = main.its.shape.material.pdf(wo: mainLightInLocal, wi: mainLightOutLocal, uv: main.its.uv, p: main.its.p)
                } else {
                    lightSample = nil
                    mainBsdfEval = .zero
                    mainBsdfPdf = 0
                    mainLightOutLocal = .zero
                }

                if let lightSample = lightSample {
                    let mainWeightNum = lightSample.pdf
                    let mainWeightDem = lightSample.pdf + mainBsdfPdf
                    let mainContrib = main.throughput * mainBsdfEval * lightSample.L
                    let mainGeometrySquaredLength = (main.its.p - lightSample.p).lengthSquared
                    let mainGeometryCosLight = lightSample.n.dot(lightSample.wi)
                    // Compute shift maps
                    for (i, o) in offsets.enumerated() {
                        let result: (shiftWeightDem: Float, shiftContrib: Color)
                        switch o {
                        case .dead: result = (mainWeightNum / (0.0001 + mainWeightDem), .zero)
                        case .connected(let s):
                            let dem = (s.pdf / main.pdf) * (lightSample.pdf + mainBsdfPdf)
                            let contrib = s.throughput * mainBsdfEval * lightSample.L
                            result = (dem, contrib)
                        case .connectedRecently(let s):
                            let shiftDirectionInGlobal = (s.its.p - main.its.p).normalized()
                            let shiftDirectionInLocal = mainFrame.toLocal(v: shiftDirectionInGlobal)
                            guard shiftDirectionInLocal.z > 0 else { result = (0.0, Color.zero); break }

                            let shiftBsdfPdf = main.its.shape.material.pdf(wo: shiftDirectionInLocal, wi: mainLightOutLocal, uv: s.its.uv, p: s.its.p)
                            let shiftBsdfValue = main.its.shape.material.evaluate(wo: shiftDirectionInLocal, wi: mainLightOutLocal, uv: s.its.uv, p: s.its.p)
                            let weightDem = (s.pdf / main.pdf) * (lightSample.pdf + shiftBsdfPdf)
                            let contrib = s.throughput * shiftBsdfValue * lightSample.L
                            result = (weightDem, contrib)
                        case .fresh(let s):
                            guard !s.its.hasEmission else { result = (0, .zero); break }
                            
                            let ctx = LightSample.Context(p: s.its.p, n: s.its.n, ns: s.its.n)
                            let frame = Frame(n: s.its.n)
                            guard let shiftLightSample = scene.sample(context: ctx, s: rngLight) else { result = (0, .zero); break }

                            let shiftEmmiterRadiance = shiftLightSample.L * (shiftLightSample.pdf / lightSample.pdf)
                            let shiftDirectionOutLocal = frame.toLocal(v: shiftLightSample.wi)
                            let shiftFrame = Frame(n: s.its.n)
                            let shiftInLocal = shiftFrame.toLocal(v: -s.ray.d)
                            let shiftBsdfValue = s.its.shape.material.evaluate(wo: shiftInLocal, wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                            let shiftBsdfPdf = s.its.shape.material.pdf(wo: shiftInLocal, wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                            let jacobian = (shiftLightSample.n.dot(shiftLightSample.wi) * mainGeometrySquaredLength).abs()
                                / (mainGeometryCosLight * (s.its.p - shiftLightSample.p).lengthSquared).abs()
                            
                            assert(jacobian.isFinite)
                            assert(jacobian >= 0)
                            let weightDem = (jacobian * (s.pdf / main.pdf)) * (shiftLightSample.pdf + shiftBsdfPdf)
                            let contrib = jacobian * s.throughput * shiftBsdfValue * shiftEmmiterRadiance
                            result = (weightDem, contrib)
                        }
                        
                        let weight = mainWeightNum / (mainWeightDem + result.shiftWeightDem)
                        assert(weight.isFinite)
                        assert(weight >= 0 && weight <= 1)
                        li.main += mainContrib * weight
                        li.radiances[i] += result.shiftContrib * weight
                        li.gradients[i] += (result.shiftContrib - mainContrib) * weight
                    }
                }
            }
        
            // BSDF Sampling
            let frame = Frame(n: main.its.n)
            let wo = frame.toLocal(v: -main.ray.d)
            guard !main.its.hasEmission, let mainSampledBsdf = main.its.shape.material.sample(wo: wo, uv: main.its.uv, p: main.its.p, sample: scene.sampler.next2()) else { return li }
            
            let mainDirectionOutGlobal = frame.toWorld(v: mainSampledBsdf.wi).normalized()
            main.ray = Ray(origin: main.its.p, direction: mainDirectionOutGlobal)
            let mainPrevIts = main.its
            guard let newIts = scene.hit(r: main.ray) else { return li }
            main.its = newIts
            
            // Verify light intersection
            let bounceLightPdf: Float
            let bounceLightRadiance: Color
            if main.its.hasEmission, let light = main.its.shape.light {
                let ctx = LightSample.Context(p: mainPrevIts.p, n: mainPrevIts.n, ns: mainPrevIts.n)
                bounceLightPdf = light.pdfLi(context: ctx, y: main.its.p)
                let frame = Frame(n: main.its.n)
                let wo = frame.toLocal(v: -main.ray.d)
                bounceLightRadiance = light.L(p: main.its.p, n: main.its.n, uv: main.its.uv, wo: wo)
            } else {
                bounceLightPdf = 0
                bounceLightRadiance = .zero
            }
            
            let mainPdfPrev = main.pdf
            main.throughput *= mainSampledBsdf.weight
            main.pdf *= mainSampledBsdf.pdf
            guard main.pdf != 0 && main.throughput != .zero else { return li }
            
            let mainBsdfContrib = main.throughput * bounceLightRadiance
            offsets = offsets.enumerated().map { (i, o) in
                let result: (weightDem: Float, contrib: Color, state: RayState)
                switch o {
                case .dead: result = (0, .zero, .dead)
                case .connected(let s):
                    let newThroughput = s.throughput * mainSampledBsdf.weight
                    let newPdf = s.pdf * mainSampledBsdf.pdf
                    let shiftWeightDem = (s.pdf / mainPdfPrev) * (mainSampledBsdf.pdf + bounceLightPdf)
                    let shiftContrib = newThroughput * bounceLightRadiance
                    result = (
                        shiftWeightDem,
                        shiftContrib,
                        .connected(data: RayState.Data(pdf: newPdf, ray: s.ray, its: s.its, throughput: newThroughput))
                    )
                case .connectedRecently(let s):
                    guard mainPrevIts.shape.material.hasDelta(uv: mainPrevIts.uv, p: mainPrevIts.p) == false else { result = (0.0, .zero, .dead); break }

                    let frame = Frame(n: mainPrevIts.n)
                    let shiftDirectionInGlobal = (s.its.p - main.ray.o).normalized()
                    let shiftDirectionInLocal = frame.toLocal(v: shiftDirectionInGlobal)
                    guard shiftDirectionInLocal.z > 0 else { result = (0.0, .zero, .dead); break }
                    
                    let shiftBsdfPdf = mainPrevIts.shape.material.pdf(wo: shiftDirectionInLocal, wi: mainSampledBsdf.wi, uv: mainPrevIts.uv, p: mainPrevIts.p)
                    let shiftBsdfValue = mainPrevIts.shape.material.evaluate(wo: shiftDirectionInLocal, wi: mainSampledBsdf.wi, uv: mainPrevIts.uv, p: mainPrevIts.p)
                    let newThroughput = s.throughput * (shiftBsdfValue / mainSampledBsdf.pdf)
                    let newPdf = s.pdf * shiftBsdfPdf
                    let shiftWeightDem = (s.pdf / mainPdfPrev) * (shiftBsdfPdf + bounceLightPdf)
                    let shiftContrib = newThroughput * bounceLightRadiance
                    result = (
                        shiftWeightDem,
                        shiftContrib,
                        .connected(data: RayState.Data(pdf: newPdf, ray: s.ray, its: s.its, throughput: newThroughput))
                    )
                case .fresh(let s):
                    guard !s.its.hasEmission && s.its.p.visible(from: main.its.p, within: scene) else { result = (0.0, .zero, .dead); break }
                    
                    let frame = Frame(n: s.its.n)
                    let shiftDirectionOutGlobal = (main.its.p - s.its.p).normalized()
                    let shiftDirectionOutLocal = frame.toLocal(v: shiftDirectionOutGlobal)
                    
                    let jacobian = (main.its.n.dot(-shiftDirectionOutGlobal) * main.its.t.pow(2)).abs()
                        / (main.its.n.dot(-main.ray.d) * (s.its.p - main.its.p).lengthSquared).abs()
                    assert(jacobian.isFinite)
                    assert(jacobian >= 0)
    
                    let shiftBsdfValue = s.its.shape.material.evaluate(wo: frame.toLocal(v: -s.ray.d), wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                    let shiftBsdfPdf = s.its.shape.material.pdf(wo: frame.toLocal(v: -s.ray.d), wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                    let newThroughput = s.throughput * shiftBsdfValue * (jacobian / mainSampledBsdf.pdf)
                    let newPdf = s.pdf * shiftBsdfPdf * jacobian
                    let shiftLightRadiance: Color
                    let shiftLightPdf: Float
                    if bounceLightPdf == 0 {
                        shiftLightRadiance = .zero
                        shiftLightPdf = 0
                    } else {
                        let ctx = LightSample.Context(p: s.its.p, n: s.its.n, ns: s.its.n)
                        shiftLightRadiance = bounceLightRadiance
                        shiftLightPdf = main.its.shape.light.pdfLi(context: ctx, y: main.its.p)
                    }
                    
                    let shiftWeightDem = (s.pdf / mainPdfPrev) * (shiftBsdfPdf + shiftLightPdf)
                    let shiftContrib = newThroughput * shiftLightRadiance
                    result = (
                        shiftWeightDem,
                        shiftContrib,
                        .connectedRecently(data: RayState.Data(pdf: newPdf, ray: s.ray, its: s.its, throughput: newThroughput))
                    )
                }
                
                let mainWeightDem = mainSampledBsdf.pdf + bounceLightPdf
                let weight = mainSampledBsdf.pdf / (mainWeightDem + result.weightDem)
                assert(weight.isFinite)
                assert(weight >= 0 && weight <= 1)
                li.main += mainBsdfContrib * weight
                li.radiances[i] += result.contrib * weight
                li.gradients[i] += (result.contrib - mainBsdfContrib) * weight
                return result.state
            }
            
            depth += 1
        }

        return li
    }
    
    func li(ray: Ray, scene: Scene, sampler: any Sampler) -> Color {
        fatalError("Not implemented")
    }
    
    func li(pixel: Vec2, scene: Scene, sampler: Sampler) -> Color {
        let result = newTrace(pixel: pixel, scene: scene)
        return result.main
    }
}
                 
// MARK:  Rendering blocks

extension GdptIntegrator: GradientDomainIntegrator {
    internal struct Block {
        let position: Vec2
        let size: Vec2
        let image: Array2d<Color>
        let dxGradients: Array2d<Color>
        let dyGradients: Array2d<Color>
    }
    
    func render(scene: Scene, sampler: any Sampler) -> GradientDomainResult {
        print("Integrator preprocessing ...")
        preprocess(scene: scene, sampler: sampler)
        
        print("Rendering ...")
        let img = Array2d<Color>(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: .zero)
        let dxGradients = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        let dyGradients = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        mapper.initialize(sampler: sampler, integrator: self, scene: scene)

        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: Int(scene.camera.resolution.x) / 32 * Int(scene.camera.resolution.y) / 32, printer: Printer())
            let blocks = await renderBlocks(scene: scene, mapper: mapper) {
                progress.next()
            }
            
            return blocks.assemble(into: img, dx: dxGradients, dy: dyGradients)
        }
        
        gcd.wait()
        
        print("Reconstructing with dx and dy ...")
        let reconstruction = reconstructor.reconstruct(image: img, dx: dxGradients, dy: dyGradients)
        
        // Rework how these stats are built within the shift happening along the main path
//        print("Successful shifts => \(successfulShifts)")
//        print("Failed shifts     => \(failedShifts)")
        return GradientDomainResult(
            img: reconstruction,
            dx: dxGradients.transformed { $0.abs },
            dy: dyGradients.transformed { $0.abs }
        )
        
    }
    
    private func renderBlocks(blockSize: Int = 32, scene: Scene, mapper: ShiftMapping, increment: @escaping () -> Void) async -> [Block] {
        return await withTaskGroup(of: Block.self) { group in
            for x in stride(from: 0, to: Int(scene.camera.resolution.x), by: blockSize) {
                for y in stride(from: 0, to: Int(scene.camera.resolution.y), by: blockSize) {
                    let size = Vec2(
                        min(scene.camera.resolution.x - Float(x), Float(blockSize)),
                        min(scene.camera.resolution.y - Float(y), Float(blockSize))
                    )
                    
                    group.addTask {
                        increment()
                        return self.renderBlock(scene: scene, size: size, x: x, y: y, mapper: mapper)
                    }
                }
            }

            var blocks: [Block] = []
            for await block in group {
                blocks.append(block)
            }
            
            return blocks
        }
    }

    private func renderBlock(scene: Scene, size: Vec2, x: Int, y: Int, mapper: ShiftMapping) -> Block {
        let img = Array2d(x: Int(size.x), y: Int(size.y), value: Color())
        let dxGradients = Array2d<Color>(x: img.xSize + 1, y: img.ySize + 1, value: .zero)
        let dyGradients = Array2d<Color>(x: img.xSize + 1, y: img.ySize + 1, value: .zero)
        for lx in 0 ..< Int(size.x) {
            for ly in 0 ..< Int(size.y) {
                for _ in 0 ..< mapper.sampler.nbSamples {
                    let x = lx + x
                    let y = ly + y

                    let base = Vec2(Float(x), Float(y)) + mapper.sampler.next2()
                    let newResult = newTrace(pixel: base, scene: scene)
                    img[lx, ly] += newResult.main
                    
                    for (i, offset) in gradientOffsets.enumerated() {
                        let xShift = lx + Int(offset.x)
                        let yShift = ly + Int(offset.y)
                        
                        // TODO Cleaner check
                        // TODO img needs to be of the same size as dx and dy now, since we reuse primal from radiances of shifted paths
                        if (0 ..< Int(size.x)).contains(xShift) && (0 ..< Int(size.y)).contains(yShift) {
                            img[xShift, yShift] += newResult.radiances[i]
                        }
                        
                        let forward = offset.sum() > 0
                        let delta = if forward { newResult.gradients[i] } else { newResult.gradients[i] * -1 }
                        if offset.x == 0 {
                            dyGradients[lx+1, forward ? ly+1 : ly] += delta
                        } else {
                            dxGradients[forward ? lx+1 : lx, ly+1] += delta
                        }
                    }
                }
            }
        }
        
        let scaleFactor: Float = 1.0 / Float(mapper.sampler.nbSamples)
        img.scale(by: scaleFactor * 0.25)
        dxGradients.scale(by: scaleFactor)
        dyGradients.scale(by: scaleFactor)
        return Block(
            position: Vec2(Float(x), Float(y)),
            size: size,
            image: img,
            dxGradients: dxGradients,
            dyGradients: dyGradients
        )
    }
}

private extension [GdptIntegrator.Block] {
    func assemble(into image: Array2d<Color>, dx: Array2d<Color>, dy: Array2d<Color>) -> GradientDomainResult {
        for block in self {
            for lx in (0 ..< Int(block.size.x)) {
                for ly in (0 ..< Int(block.size.y)) {
                    let (x, y): (Int, Int) = (lx + Int(block.position.x), ly + Int(block.position.y))
                    image[x, y] = block.image[lx, ly]
                    if lx == 0 && x != 0 { dx[x - 1, y] += block.dxGradients[lx, ly] }
                    if ly == 0 && y != 0 { dy[x, y - 1] += block.dyGradients[lx, ly] }
                    dx[x, y] += block.dxGradients[lx+1, ly+1]
                    dy[x, y] += block.dyGradients[lx+1, ly+1]
                }
            }
        }
        
        return GradientDomainResult(img: image, dx: dx, dy: dy)
    }
}

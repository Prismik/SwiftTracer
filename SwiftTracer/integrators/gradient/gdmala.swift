//
//  gdmala.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2025-02-06.
//

import Collections

final class GdmalaIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case shiftMapping
        case samplesPerChain
        case initSamplesCount
        case reconstruction
        case step
    }
    
    struct KernelGradientState {
        let contrib: Color
        let pos: Vec2
        var weight: Float = 0
        let targetFunction: Float
        let shiftContrib: [Color]
        let directLight: Color
        let delta: [Color]
        let offsets: OrderedSet = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]
        
        init(contrib: Color, pos: Vec2, directLight: Color, shiftContribs: [Color], gradients: [Color], alpha: Float = 0.2) {
            self.contrib = contrib
            self.pos = pos
            self.directLight = directLight
            self.shiftContrib = shiftContribs
            let offsets = self.offsets // Weird quirk about accessing self.delta
            self.delta = gradients.enumerated().map({ (i, gradient) in
                let forward = offsets[i].sum() > 0
                return if forward { gradient } else { gradient * -1 }
            })
            self.targetFunction = 0
        }
    }
    
    private class MarkovChain {
        private(set) var img: PixelBuffer
        private(set) var dx: PixelBuffer
        private(set) var dy: PixelBuffer
        private(set) var directLight: PixelBuffer
        
        init(x: Int, y: Int) {
            self.img = PixelBuffer(width: x, height: y, value: .zero)
            self.dx = PixelBuffer(width: x, height: y, value: .zero)
            self.dy = PixelBuffer(width: x, height: y, value: .zero)
            self.directLight = PixelBuffer(width: x, height: y, value: .zero)
        }
        
        private let offsets: [Vec2] = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]
        
        func add(state: KernelGradientState) {
            let w = state.targetFunction <= 0
                ? 0
                : state.weight / state.targetFunction
            
            let x = Int(state.pos.x)
            let y = Int(state.pos.y)
            img[x, y] += state.contrib * w
            directLight[x, y] += state.directLight * w
            
            for (i, offset) in offsets.enumerated() {
                let x2 = Int(state.pos.x + offset.x)
                let y2 = Int(state.pos.y + offset.y)
                
                if (0 ..< img.width).contains(x2) && (0 ..< img.height).contains(y2) {
                    img[x2, y2] += state.shiftContrib[i] * w
                }
                
                let forward = offset.sum() > 0

                if offset.x == 0 {
                    let lx = x
                    let ly = forward ? y : y - 1
                    if (0 ..< dy.width).contains(lx) && (0 ..< dy.height).contains(ly) {
                        dy[lx, ly] += state.delta[i] * w
                    }
                } else {
                    let lx = forward ? x : x - 1
                    let ly = y
                    if (0 ..< dx.width).contains(lx) && (0 ..< dx.height).contains(ly) {
                        dx[lx, ly] += state.delta[i] * w
                    }
                }
            }
        }
    }

    private struct StartupSeed {
        let value: UInt64
        let targetFunction: Float
    }
    
    let identifier = "gdmlt"
    let mapper: any ShiftMapping
    
    /// Samples Per Chain
    private let nspc: Int
    /// Initialization Samples Count
    private let isc: Int
    /// Samples per pixel (can derive total sample from this).
    private var nspp: Int = 10
    private let step: Float
    
    private var result: GradientDomainResult?

    private let reconstructor: Reconstructing
    
    private let shifts: [Vec2] = [Vec2(0, 1), Vec2(1, 0), Vec2(0, -1), Vec2(-1, 0)]
    
    private var b: Float = 0
    private var cdf = DistributionOneDimention(count: 0)
    private var seeds: [StartupSeed] = []
    
    private var stats: (small: PSSMLTSampler.Stats, large: PSSMLTSampler.Stats)
    
    init(mapper: ShiftMapping, reconstructor: Reconstructing, samplesPerChain: Int, initSamplesCount: Int, step: Float) {
        self.mapper = mapper
        self.reconstructor = reconstructor
        self.nspc = samplesPerChain
        self.isc = initSamplesCount
        self.step = step
        self.stats = (.init(times: 0, accept: 0, reject: 0), .init(times: 0, accept: 0, reject: 0))
    }
    
    func render(scene: Scene, sampler: any Sampler) -> PixelBuffer {
        let result: GradientDomainResult = render(scene: scene, sampler: sampler)
        return result.img
    }
    
    /// Computes the normalization factor
    private func normalizationConstant(scene: Scene, sampler: Sampler) -> (Float, DistributionOneDimention, [StartupSeed]) {
        var seeds: [StartupSeed] = []
        let b = (0 ..< isc).map { _ in
            let currentSeed = sampler.rng.state
            
            let s = sample(scene: scene, sampler: sampler, mapper: mapper)
            let validSample = s.targetFunction.isFinite && !s.targetFunction.isNaN && !s.targetFunction.isZero
            if validSample {
                let values = StartupSeed(
                    value: currentSeed,
                    targetFunction: s.targetFunction
                )
                seeds.append(values)
            }

            let shiftLuminance = s.shiftContrib.reduce(Color(), +).luminance
            return validSample ? s.contrib.luminance + shiftLuminance: 0
            //return validSample ? s.contrib.luminance: 0
        }.reduce(0, +) / Float(isc * 4)
        
        guard b != 0 else { fatalError("Invalid computation of b") }
        var cdf = DistributionOneDimention(count: seeds.count)
        for s in seeds {
            cdf.add(s.targetFunction)
        }
        
        print("Seeds count => \(seeds.count)")
        cdf.normalize()
        return (b, cdf, seeds)
    }
    
    private func sample(scene: Scene, sampler: Sampler, mapper: ShiftMapping) -> KernelGradientState {
        let rng2 = sampler.next2()

        let x = min(scene.camera.resolution.x * rng2.x, scene.camera.resolution.x - 1)
        let y = min(scene.camera.resolution.y * rng2.y, scene.camera.resolution.y - 1)
        let pixel = Vec2(Float(x), Float(y))
        let result = mapper.shift(pixel: pixel, sampler: sampler, params: ShiftMappingParams(offsets: nil))

        return KernelGradientState(
            contrib: result.main,
            pos: pixel,
            directLight: result.directLight,
            shiftContribs: result.radiances,
            gradients: result.gradients
        )
    }
}

extension GdmalaIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: any Sampler) {
        mapper.initialize(scene: scene)
        let (b, cdf, seeds) = normalizationConstant(scene: scene, sampler: sampler)
        self.b = b
        self.cdf = cdf
        self.seeds = seeds
    }
    
    func li(ray: Ray, scene: Scene, sampler: any Sampler) -> Color {
        fatalError("Not implemented")
    }
    
    func li(pixel: Vec2, scene: Scene, sampler: Sampler) -> Color {
        fatalError("Not implemented")
    }
}

extension GdmalaIntegrator: GradientDomainIntegrator {
    func reconstruct(using gdr: GradientDomainResult) -> GradientDomainResult {
        print("Reconstructing with dx and dy ...")
        let reconstruction = reconstructor.reconstruct(gradientDomainResult: gdr)
        return GradientDomainResult(
            primal: gdr.primal,
            directLight: gdr.directLight,
            img: reconstruction,
            dx: gdr.dx,
            dy: gdr.dy
        )
    }
    
    func render(scene: Scene, sampler: any Sampler) -> GradientDomainResult {
        let img = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
        let primal = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
        let dx = PixelBuffer(width: img.width, height: img.height, value: .zero)
        let dy = PixelBuffer(width: img.width, height: img.height, value: .zero)
        let directLight = PixelBuffer(width: img.width, height: img.height, value: .zero)
        
        return GradientDomainResult(
            primal: primal,
            directLight: directLight,
            img: img,
            dx: dx,
            dy: dy
        )
    }
    
    private func chains(samples: Int, nbChains: Int, scene: Scene, increment: @escaping () -> Void) async -> GradientDomainResult {
        return await withTaskGroup(of: Void.self, returning: GradientDomainResult.self) { group in
            let img = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
            let primal = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
            let dx = PixelBuffer(width: img.width, height: img.height, value: .zero)
            let dy = PixelBuffer(width: img.width, height: img.height, value: .zero)
            let directLight = PixelBuffer(width: img.width, height: img.height, value: .zero)
            var result = GradientDomainResult(primal: primal, directLight: directLight, img: img, dx: dx, dy: dy)
            var processed = 0
            for i in 0 ..< nbChains {
                group.addTask {
                    increment()
                    return self.renderChain(i: i, total: samples, nbChains: nbChains, scene: scene, into: &result)
                }
            }
            
            for await _ in group {
                processed += 1
            }
            
            return result
        }
    }
        
    private func renderChain(i: Int, total: Int, nbChains: Int, scene: Scene, into acc: inout GradientDomainResult) -> Void {
        let id = (Float(i) + 0.5) / Float(nbChains)
        let i = cdf.sampleDiscrete(id)
        let seed = seeds[i]
        let sampler = PSSMLTSampler(nbSamples: nspp, largeStepRatio: 0.3, mutator: KelemenMutation())
        let previousSeed = sampler.rng.state
        sampler.rng.state = seed.value
        
        // Reinitialize with appropriate sampler
        let chain = MarkovChain(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y))
        sampler.step = .large
        
        var state = sample(scene: scene, sampler: sampler, mapper: mapper)
        guard state.targetFunction == seed.targetFunction else { fatalError("Inconsistent seed-sample") }
        sampler.accept()

        sampler.rng.state = previousSeed
        
        for _ in 0 ..< nspc {
            sampler.step = Float.random(in: 0 ... 1) < sampler.largeStepRatio
                ? .large
                : .small
            
            var proposedState = sample(scene: scene, sampler: sampler, mapper: mapper)
            let acceptProbability = proposedState.targetFunction < 0 || proposedState.contrib.hasNaN
                ? 0
                : min(1.0, proposedState.targetFunction / state.targetFunction)
            
            state.weight += 1.0 - acceptProbability
            proposedState.weight += acceptProbability
            
            if acceptProbability == 1 || acceptProbability > Float.random(in: 0 ... 1) {
                chain.add(state: state)
                sampler.accept()
                state = proposedState
            } else {
                chain.add(state: proposedState)
                sampler.reject()
            }
        }
        
        // b * F / (TF * totalSample)
        // let scale = b / (state.targetFunction * Float(total))
        chain.add(state: state)
        
        let scale = 1 / Float(nspc)
        // TODO whats the proper value for single gradient state
        chain.img.scale(by: scale * 0.25)
        chain.dx.scale(by: scale)
        chain.dy.scale(by: scale)
        chain.directLight.scale(by: scale)
        acc.primal.merge(with: chain.img)
        acc.dx.merge(with: chain.dx)
        acc.dy.merge(with: chain.dy)
        acc.directLight.merge(with: chain.directLight)

        stats.small.combine(with: sampler.smallStats)
        stats.large.combine(with: sampler.largeStats)
    }
}

private extension PSSMLTSampler.Stats {
    mutating func combine(with other: Self) {
        self.times += other.times
        self.accept += other.accept
        self.reject += other.reject
    }
}

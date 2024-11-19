//
//  gdmlt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-18.
//

import Foundation
import Progress

protocol GradientStateMCMC {
    var pos: Vec2 { get }
    var weight: Float { get set }
    var targetFunction: Float { get }
    var offsets: [Vec2] { get }
    var delta: [Color] { get }
    var shiftContrib: [Color] { get }
    var contrib: Color { get }
    var directLight: Color { get }
}

final class GdmltIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case shiftMapping
        case samplesPerChain
        case initSamplesCount
        case reconstruction
    }

    internal enum StrategyGradientMCMC {
        case multi
        case single
        
        var scalingFactor: Float {
            switch self {
            case .single: return 0.25
            case .multi: return 0.25
            }
        }
        func sample(scene: Scene, sampler: Sampler, mapper: ShiftMapping, cdf: DistributionOneDimention) -> GradientStateMCMC {
            return switch self {
                case .multi: MultiStateMCMC.sample(scene: scene, sampler: sampler, mapper: mapper, cdf: cdf)
                case .single: SingleStateMCMC.sample(scene: scene, sampler: sampler, mapper: mapper, cdf: cdf)
            }
        }
    }
    
    internal struct MultiStateMCMC: GradientStateMCMC {
        let contrib: Color
        var pos: Vec2
        var weight: Float = 0
        var targetFunction: Float = 0
        let delta: [Color]
        let shiftContrib: [Color]
        let directLight: Color
        let offsets = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]

        init(contrib: Color, pos: Vec2, directLight: Color, shiftContribs: [Color], gradients: [Color], alpha: Float = 0.2) {
            self.contrib = contrib
            self.pos = pos
            self.shiftContrib = shiftContribs
            self.directLight = directLight
            let offsets = self.offsets // Weird quirk about accessing self.delta
            self.delta = gradients.enumerated().map({ (i, gradient) in
                let forward = offsets[i].sum() > 0
                let nz: Float = contrib != .zero && shiftContribs[i] != .zero
                    ? 0.5
                    : 1
                return if forward { gradient * nz } else { gradient * nz * -1 }
            })

            let gradientLuminance: Float = offsets.enumerated().reduce(into: 0) { (acc, pair) in
                let (i, _) = pair
                acc += delta[i].abs.luminance
            }
            
            let luminance = contrib.abs.luminance + directLight.abs.luminance
            self.targetFunction = gradientLuminance + alpha * luminance
        }
        
        static func sample(scene: Scene, sampler: Sampler, mapper: ShiftMapping, cdf: DistributionOneDimention) -> GradientStateMCMC {
            let rng2 = sampler.next2()

            let x = min(scene.camera.resolution.x * rng2.x, scene.camera.resolution.x - 1)
            let y = min(scene.camera.resolution.y * rng2.y, scene.camera.resolution.y - 1)
            let pixel = Vec2(Float(x), Float(y))
            let result = mapper.shift(pixel: pixel, sampler: sampler, params: ShiftMappingParams(offsets: nil))

            return MultiStateMCMC(
                contrib: result.main,
                pos: pixel,
                directLight: result.directLight,
                shiftContribs: result.radiances,
                gradients: result.gradients
            )
        }
    }
    
    internal struct SingleStateMCMC: GradientStateMCMC {
        var pos: Vec2
        var contrib: Color
        let shiftContrib: [Color]
        let directLight: Color
        var weight: Float = 0
        var targetFunction: Float = 0
        let delta: [Color]
        let offsets: [Vec2]

        private static let shifts: [Vec2] = [Vec2(0, 1), Vec2(1, 0), Vec2(0, -1), Vec2(-1, 0)]

        init(contrib: Color, pos: Vec2, offset: Vec2, directLight: Color, shiftContrib: Color, gradient: Color, alpha: Float = 0.2) {
            self.contrib = contrib
            self.pos = pos
            self.offsets = [offset]
            self.shiftContrib = [shiftContrib]
            self.directLight = directLight

            let forward = offset.sum() > 0
            self.delta = if forward { [gradient] } else { [gradient * -1] }
            
            let luminance = contrib.luminance.abs() + directLight.luminance.abs()
            let gradientLuminance = delta[0].luminance.abs()
            self.targetFunction = gradientLuminance + alpha * (0.25 * luminance)
        }
        
        static func sample(scene: Scene, sampler: Sampler, mapper: ShiftMapping, cdf: DistributionOneDimention) -> GradientStateMCMC {
            let rng2 = sampler.next2()

            let id = cdf.sampleDiscrete(sampler.next())
            let x = min(scene.camera.resolution.x * rng2.x, scene.camera.resolution.x - 1)
            let y = min(scene.camera.resolution.y * rng2.y, scene.camera.resolution.y - 1)
            let pixel = Vec2(Float(x), Float(y))
            let result = mapper.shift(pixel: pixel, sampler: sampler, params: ShiftMappingParams(offsets: [shifts[id]]))

            let nz: Float = result.main != .zero && result.radiances[id] != .zero
                ? 0.5
                : 1
            
            return SingleStateMCMC(
                contrib: result.main,
                pos: pixel,
                offset: shifts[id],
                directLight: result.directLight,
                shiftContrib: result.radiances[id],
                gradient: result.gradients[id] * nz
            )
        }
    }
    
    private class MarkovChain {
        private(set) var img: Array2d<Color>
        private(set) var dx: Array2d<Color>
        private(set) var dy: Array2d<Color>
        private(set) var directLight: Array2d<Color>
        
        init(x: Int, y: Int) {
            self.img = Array2d(x: x, y: y, value: .zero)
            self.dx = Array2d(x: x, y: y, value: .zero)
            self.dy = Array2d(x: x, y: y, value: .zero)
            self.directLight = Array2d(x: x, y: y, value: .zero)
        }

        // TODO Rework this
        func add(state: inout GradientStateMCMC) {
            let w = state.targetFunction <= 0
                ? 0
                : state.weight / state.targetFunction
            
            let x = Int(state.pos.x)
            let y = Int(state.pos.y)
            img[x, y] += state.contrib * w
            directLight[x, y] += state.directLight * w
            
            for (i, offset) in state.offsets.enumerated() {
                let x2 = Int(state.pos.x + offset.x)
                let y2 = Int(state.pos.y + offset.y)
                
                if (0 ..< img.xSize).contains(x2) && (0 ..< img.ySize).contains(y2) {
                    img[x2, y2] += state.shiftContrib[i] * w
                }
                
                let forward = offset.sum() > 0

                if offset.x == 0 {
                    let lx = x
                    let ly = forward ? y : y - 1
                    if (0 ..< dy.xSize).contains(lx) && (0 ..< dy.ySize).contains(ly) {
                        dy[lx, ly] += state.delta[i] * w
                    }
                } else {
                    let lx = forward ? x : x - 1
                    let ly = y
                    if (0 ..< dx.xSize).contains(lx) && (0 ..< dx.ySize).contains(ly) {
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
    
    /// Samples Per Chain
    private let nspc: Int
    /// Initialization Samples Count
    private let isc: Int
    /// Samples per pixel (can derive total sample from this).
    private var nspp: Int = 10

    private var result: GradientDomainResult?

    private let strategy: StrategyGradientMCMC = .multi
    private let integrator: SamplerIntegrator
    private let reconstructor: Reconstructing
    let mapper: any ShiftMapping
    private let shiftCdf: DistributionOneDimention
    private let shifts: [Vec2] = [Vec2(0, 1), Vec2(1, 0), Vec2(0, -1), Vec2(-1, 0)]
    
    private var b: Float = 0
    private var cdf = DistributionOneDimention(count: 0)
    private var seeds: [StartupSeed] = []
    
    private var stats: (small: PSSMLTSampler.Stats, large: PSSMLTSampler.Stats)

    init(mapper: ShiftMapping, reconstructor: Reconstructing, samplesPerChain: Int, initSamplesCount: Int) {
        self.mapper = mapper
        self.integrator = PathIntegrator(minDepth: 0, maxDepth: 16)
        self.reconstructor = reconstructor
        var cdf = DistributionOneDimention(count: shifts.count)
        for _ in 0 ..< shifts.count {
            cdf.add(0.25)
        }
        cdf.normalize()
        self.shiftCdf = cdf
        self.nspc = samplesPerChain
        self.isc = initSamplesCount
        self.stats = (.init(times: 0, accept: 0, reject: 0), .init(times: 0, accept: 0, reject: 0))
    }

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let result: GradientDomainResult = render(scene: scene, sampler: sampler)
        return result.img
    }
}

extension GdmltIntegrator: SamplerIntegrator {
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

extension GdmltIntegrator: GradientDomainIntegrator {
    func render(scene: Scene, sampler: any Sampler) -> GradientDomainResult {
        self.nspp = sampler.nbSamples
        let totalSamples = nspp * Int(scene.camera.resolution.x) * Int(scene.camera.resolution.y)
        let nbChains = totalSamples / nspc
        
        print("GDMLT Rendering with \(mapper.identifier)...")
        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: nbChains, printer: Printer())
            let result = await chains(samples: totalSamples, nbChains: nbChains, scene: scene) { progress.next() }
            self.result = result
        }
        gcd.wait()
        
        guard var result = result else { fatalError("No result image was returned in the async task") }

        let combinedAvg = (result.primal.total.luminance + result.directLight.total.luminance) / Float(result.primal.size)
        result.scale(by: b / combinedAvg)
        
        print("smallStepCount => \(stats.small.times)")
        print("largeStepCount => \(stats.large.times)")
        print("smallStepAcceptRatio => \(Float(stats.small.accept) / Float(stats.small.accept + stats.small.reject))")
        print("largeStepAcceptRatio => \(Float(stats.large.accept) / Float(stats.large.accept + stats.large.reject))")
        print("Average luminance => \(combinedAvg)")
        print("b => \(b)")

        return GradientDomainResult(
            primal: result.primal,
            directLight: result.directLight,
            img: result.img,
            dx: result.dx,
            dy: result.dy
        )
    }
    
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
    
    /// Computes the normalization factor
    private func normalizationConstant(scene: Scene, sampler: Sampler) -> (Float, DistributionOneDimention, [StartupSeed]) {
        var seeds: [StartupSeed] = []
        var totalValid = isc
        let b = (0 ..< isc).map { _ in
            let currentSeed = sampler.rng.state
            
            let s = strategy.sample(scene: scene, sampler: sampler, mapper: mapper, cdf: shiftCdf)
            let validSample = s.targetFunction.isFinite && !s.targetFunction.isNaN && !s.targetFunction.isZero
            if validSample {
                let values = StartupSeed(
                    value: currentSeed,
                    targetFunction: s.targetFunction
                )
                seeds.append(values)
            } else {
                totalValid -= 1
            }

            return validSample ? s.contrib.luminance : 0
        }.reduce(0, +) / Float(totalValid)
        
        guard b != 0 else { fatalError("Invalid computation of b") }
        var cdf = DistributionOneDimention(count: seeds.count)
        for s in seeds {
            cdf.add(s.targetFunction)
        }
        
        print("Seeds count => \(seeds.count)")
        cdf.normalize()
        return (b, cdf, seeds)
    }
    
    private func chains(samples: Int, nbChains: Int, scene: Scene, increment: @escaping () -> Void) async -> GradientDomainResult {
        return await withTaskGroup(of: Void.self, returning: GradientDomainResult.self) { group in
            let img = Array2d<Color>(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: .zero)
            let primal = Array2d<Color>(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: .zero)
            let dx = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
            let dy = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
            let directLight = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
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
        let sampler = PSSMLTSampler(nbSamples: nspp)
        let previousSeed = sampler.rng.state
        sampler.rng.state = seed.value
        
        // Reinitialize with appropriate sampler
        let chain = MarkovChain(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y))
        sampler.step = .large
        
        var state = strategy.sample(scene: scene, sampler: sampler, mapper: mapper, cdf: shiftCdf)
        guard state.targetFunction == seed.targetFunction else { fatalError("Inconsistent seed-sample") }
        sampler.accept()

        sampler.rng.state = previousSeed
        
        for _ in 0 ..< nspc {
            sampler.step = Float.random(in: 0 ... 1) < sampler.largeStepRatio
                ? .large
                : .small
            
            var proposedState = strategy.sample(scene: scene, sampler: sampler, mapper: mapper, cdf: shiftCdf)
            let acceptProbability = proposedState.targetFunction < 0 || proposedState.contrib.hasNaN
                ? 0
                : min(1.0, proposedState.targetFunction / state.targetFunction)
            
            state.weight += 1.0 - acceptProbability
            proposedState.weight += acceptProbability
            
            if acceptProbability == 1 || acceptProbability > Float.random(in: 0 ... 1) {
                chain.add(state: &state)
                sampler.accept()
                state = proposedState
            } else {
                chain.add(state: &proposedState)
                sampler.reject()
            }
        }
        
        // b * F / (TF * totalSample)
        // let scale = b / (state.targetFunction * Float(total))
        chain.add(state: &state)
        
        let scale = 1 / Float(nspc)
        // TODO whats the proper value for single gradient state
        chain.img.scale(by: scale * strategy.scalingFactor)
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

//
//  mala.swift
//  SwiftTracer
//
//  Created by Francis on 2025-01-20.
//

import Collections
import Foundation
import Progress

final class MalaIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case shiftMapping
        case samplesPerChain
        case initSamplesCount
        case step
        case mutator
        case maxDepth
        case normalization
    }
    
    let identifier = "mala"

    internal struct StateMala {
        var contrib: Color
        var contribPrime: Color
        var u: Vec2
        var pos: Vec2
        var gradient: Vec2
        var weight: Float = 0
        var targetFunction: Float = 0
        var shiftContrib: [Color]
        var directLight: Color
        let offsets: OrderedSet = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]
        let acceptanceTerm: Vec2
        
        init(contrib: Color, contribPrime: Color, direct: Color, shiftContrib: [Color], u: Vec2, pos: Vec2, gradient: Vec2, step: Float, acceptanceTerm: Vec2) {
            if contrib.luminance > 100 {
                self.contrib = contrib / contrib.luminance
            } else {
                self.contrib = contrib
            }
            
            if contribPrime.luminance > 100 {
                self.contribPrime = (contribPrime / contribPrime.luminance) + direct
            } else {
                self.contribPrime = contribPrime + direct
            }
            self.directLight = direct
            self.shiftContrib = shiftContrib.map {
                if $0.luminance * 4 > 100 { $0 / $0.luminance } else { $0 }
            }
            self.u = u
            self.pos = pos
            self.gradient = gradient
            self.targetFunction = self.contrib.abs.luminance + directLight.abs.luminance
            self.acceptanceTerm = acceptanceTerm
        }
    }
    
    private class MarkovChain {
        private(set) var img: PixelBuffer
        private(set) var directLight: PixelBuffer

        init(blank: PixelBuffer) {
            self.img = PixelBuffer(copy: blank)
            self.directLight = PixelBuffer(copy: blank)
        }

        func add(state: inout StateMala) {
            let w = state.targetFunction == 0
                ? 0
                : state.weight / state.targetFunction
            let x = Int(state.pos.x)
            let y = Int(state.pos.y)
            img[x, y] += state.contrib * w
            directLight[x, y] += state.directLight * w
            
            state.weight = 0
            // Reuse primal
            for (i, offset) in state.offsets.enumerated() {
                let x2 = Int(state.pos.x + offset.x)
                let y2 = Int(state.pos.y + offset.y)
                if (0 ..< img.width).contains(x2) && (0 ..< img.height).contains(y2) {
                    img[x2, y2] += state.shiftContrib[i] * w
                }
            }
        }
    }
    
    private struct StartupSeed {
        let value: UInt64
        let targetFunction: Float
    }

    /// Samples Per Chain
    private let spc: Int
    /// Initialization Samples Count
    private let isc: Int
    /// Step increment for discrete Langevin diffusion
    private let step: Float
    /// Samples per pixel (can derive total sample from this).
    private var nspp: Int = 10
    
    private var stats: (small: PSSMLTSampler.Stats, large: PSSMLTSampler.Stats)
    private var b: Float
    private var cdf = DistributionOneDimention(count: 0)
    private var seeds: [StartupSeed] = []
    private var result: PixelBuffer?
    
    private let mapper: ShiftMapping
    private let integrator: SamplerIntegrator
    private let mutator: PrimarySpaceMutation.Type
    private let maxDepth: Int
    
    private let offsets: OrderedSet = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]
    private var blankBuffer: PixelBuffer!

    init(mapper: ShiftMapping, samplesPerChain: Int, initSamplesCount: Int, step: Float, mutator: PrimarySpaceMutation.Type, maxDepth: Int, normalization: Float?) {
        self.mapper = mapper
        self.spc = samplesPerChain
        self.isc = initSamplesCount
        self.step = step
        self.integrator = PathIntegrator(minDepth: 0, maxDepth: 16)
        self.mutator = mutator
        self.maxDepth = maxDepth
        self.stats = (.init(times: 0, accept: 0, reject: 0), .init(times: 0, accept: 0, reject: 0))
        self.b = normalization ?? 0
    }

    func preprocess(scene: Scene, sampler: any Sampler) {
        mapper.initialize(scene: scene)
        let (b, cdf, seeds) = normalizationConstant(scene: scene, sampler: sampler)
        if self.b == 0 {
            self.b = b
        }
        self.cdf = cdf
        self.seeds = seeds
    }
    
    func render(scene: Scene, sampler: any Sampler) -> PixelBuffer {
        self.nspp = sampler.nbSamples
        let x = Int(scene.camera.resolution.x)
        let y = Int(scene.camera.resolution.y)
        let totalSamples = nspp * x * y
        let nbChains = totalSamples / spc
        self.blankBuffer = PixelBuffer(width: x, height: y, value: .zero)
        print("Rendering mala with \(mapper.identifier)")
        // Run chains in parallel
        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: nbChains, printer: Printer())
            let img = await chains(samples: totalSamples, nbChains: nbChains, seeds: seeds, cdf: cdf, scene: scene) {
                progress.next()
            }
            self.result = img
        }
        gcd.wait()
        
        guard let image = result else { fatalError("No result image was returned in the async task") }
        let average = image.total.luminance / Float(image.size)
        
        print("largeStepCount => \(stats.large.times)")
        print("smallStepCount => \(stats.small.times)")
        print("smallStepAcceptRatio => \(Float(stats.small.accept) / Float(stats.small.accept + stats.small.reject))")
        print("largeStepAcceptRatio => \(Float(stats.large.accept) / Float(stats.large.accept + stats.large.reject))")
        print("average => \(average)")
        print("b => \(b)")

        image.scale(by: b / average)
        
        return image
    }
    
    func sample(scene: Scene, sampler: Sampler) -> StateMala {
        let rng2 = sampler.next2()

        let x = min(scene.camera.resolution.x * rng2.x, scene.camera.resolution.x - 1)
        let y = min(scene.camera.resolution.y * rng2.y, scene.camera.resolution.y - 1)
        let pixel = Vec2(Float(x), Float(y))
        let result = mapper.shift(pixel: pixel, sampler: sampler, params: ShiftMappingParams(offsets: nil, maxDepth: maxDepth))
        let dx = (result.radiances[1] - result.radiances[0]) * 0.5
        let dy = (result.radiances[3] - result.radiances[2]) * 0.5
        let gradient = Vec2(dx.luminance, dy.luminance)

        // TODO More elegant way of setting up parameter based mutations
        var acceptanceTerm: Vec2 = .zero
        if let s = sampler as? PSSMLTSampler {
            if let m = s.mutator as? MalaMutation {
                m.setup(step: step, gradient: gradient)
                acceptanceTerm = m.acceptanceTerm
            }
            
            if let m = s.mutator as? MalaAdamMutation {
                m.setup(step: step, gradient: gradient)
                acceptanceTerm = m.acceptanceTerm
            }
        }
        
        return StateMala(
            contrib: result.main,
            contribPrime: result.mainPrime,
            direct: result.directLight,
            shiftContrib: result.radiances,
            u: rng2,
            pos: pixel,
            gradient: gradient,
            step: step,
            acceptanceTerm: acceptanceTerm
        )
    }
    
    /// Create the async blocks responsible for rendering with a Markov Chain
    private func chains(samples: Int, nbChains: Int, seeds: [StartupSeed], cdf: DistributionOneDimention, scene: Scene, increment: @escaping () -> Void) async -> PixelBuffer {
        return await withTaskGroup(of: Void.self, returning: PixelBuffer.self) { group in
            let image = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: Color())
            var processed = 0
            for i in 0 ..< nbChains {
                group.addTask {
                    increment()
                    return self.renderChain(i: i, total: nbChains, seeds: seeds, cdf: cdf, scene: scene, into: image)
                }
            }
            
            for await _ in group {
                processed += 1
            }
            
            return image
        }
    }

    private func initSample(scene: Scene, sampler: Sampler) -> Float {
        let rng2 = sampler.next2()
        let x = min(scene.camera.resolution.x * rng2.x, scene.camera.resolution.x - 1)
        let y = min(scene.camera.resolution.y * rng2.y, scene.camera.resolution.y - 1)
        let contrib = integrator.li(pixel: Vec2(Float(x), Float(y)), scene: scene, sampler: sampler)
        return contrib.luminance
    }
    
    /// Computes the normalization factor
    /// TODO Bring back shift mapping samples here and fix b
    private func normalizationConstant(scene: Scene, sampler: Sampler) -> (Float, DistributionOneDimention, [StartupSeed]) {
        var seeds: [StartupSeed] = []
        let b = (0 ..< isc).map { _ in
            let currentSeed = sampler.rng.state
            
            let s = sample(scene: scene, sampler: sampler)
            let validSample = s.targetFunction.isFinite && !s.targetFunction.isNaN && !s.targetFunction.isZero
            if validSample {
                let values = StartupSeed(
                    value: currentSeed,
                    targetFunction: s.targetFunction
                )
                seeds.append(values)
            }

            let shiftLuminance = s.shiftContrib.reduce(Color(), +).luminance
            return validSample ? s.contribPrime.luminance + shiftLuminance : 0
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
    
    /// Random walk rendering of MCMC
    private func renderChain(i: Int, total: Int, seeds: [StartupSeed], cdf: DistributionOneDimention, scene: Scene, into image: PixelBuffer) -> Void {
        let id = (Float(i) + 0.5) / Float(total)
        let i = cdf.sampleDiscrete(id)
        let seed = seeds[i]
        let mutator = mutator.init()
        let sampler = PSSMLTSampler(nbSamples: nspp, mutator: mutator)
        let previousSeed = sampler.rng.state
        sampler.rng.state = seed.value
        
        let chain = MarkovChain(blank: blankBuffer)
        sampler.step = .large
        
        var state = self.sample(scene: scene, sampler: sampler)
        // Double check reusing the shift mapping
        guard state.targetFunction == seed.targetFunction else { fatalError("Inconsistent seed-sample") }
        sampler.accept()
        
        sampler.rng.state = previousSeed
        
        for _ in 0 ..< self.spc {
            sampler.step = Float.random(in: 0 ... 1) < sampler.largeStepRatio
                ? .large
                : .small
            
            var proposedState = self.sample(scene: scene, sampler: sampler)
            let acceptProbability = proposedState.targetFunction < 0 || proposedState.contrib.hasNaN
                ? 0
                : acceptance(u: state, v: proposedState)
            
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
        
        // Flush the last state
        let scale = 1 / Float(spc)
        chain.add(state: &state)
        chain.img.scale(by: scale * 0.25)
        chain.directLight.scale(by: scale)
        image.merge(with: chain.img)
        image.merge(with: chain.directLight)
        stats.small.combine(with: sampler.smallStats)
        stats.large.combine(with: sampler.largeStats)
    }

    // q(u|v)
    // GaussianLogPdf in langevin-MCMC
    private func transitionProbDensity(u: StateMala, v: StateMala) -> Float {
        let q = -(u.u - v.u - v.acceptanceTerm).lengthSquared / (4 * step)
        return exp(q)
    }
    
    // a = min(1, π(v) q(u|v) / π(u) q(v|u))
    private func acceptance(u: StateMala, v: StateMala) -> Float {
        let num = v.targetFunction * transitionProbDensity(u: u, v: v)
        let dem = u.targetFunction * transitionProbDensity(u: v, v: u)
        return min(1, num / dem)
    }
}

private extension PSSMLTSampler.Stats {
    mutating func combine(with other: Self) {
        self.times += other.times
        self.accept += other.accept
        self.reject += other.reject
    }
}

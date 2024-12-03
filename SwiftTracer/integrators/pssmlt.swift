//
//  pssmlt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-09-10.
//

import Foundation
import Progress

final class PssmltIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        /// Number of samples that will be generated within each Markov chain.
        case samplesPerChain
        /// Number of samples used for generating the normalization constant `b`.
        case initSamplesCount
        /// Underlying integrator used to render the pixels.
        case integrator
        case heatmap
    }
    
    internal struct StateMCMC {
        var pos: Vec2
        var contrib: Color
        var weight: Float = 0
        var targetFunction: Float = 0
        
        init(contrib: Color, pos: Vec2) {
            self.contrib = contrib
            self.pos = pos
            self.targetFunction = contrib.luminance
        }
    }

    private class MarkovChain {
        private(set) var img: PixelBuffer
        
        init(x: Int, y: Int) {
            img = PixelBuffer(width: x, height: y, value: .zero)
        }

        // TODO inout not necessary with current way weights are built
        func add(state: inout StateMCMC, heatmap: inout Heatmap?) {
            let w = state.targetFunction == 0
                ? 0
                : state.weight / state.targetFunction
            let x = Int(state.pos.x)
            let y = Int(state.pos.y)
            img[x, y] += state.contrib * w
            state.weight = 0
            heatmap?.increment(at: state.pos)
        }
    }
    
    let identifier = "pssmlt"

    // TODO Allow to plug and play this thing
    private let integrator: SamplerIntegrator
    /// Samples Per Chain
    private let nspc: Int
    /// Initialization Samples Count
    private let isc: Int
    /// Samples per pixel (can derive total sample from this).
    private var nspp: Int = 10

    private var result: PixelBuffer?
    private var stats: (small: PSSMLTSampler.Stats, large: PSSMLTSampler.Stats)

    private var b: Float = 0
    private var cdf = DistributionOneDimention(count: 0)
    private var seeds: [(Float, UInt64)] = []
    private var heatmap: Heatmap?
    
    init(samplesPerChain: Int, initSamplesCount: Int, integrator: SamplerIntegrator, heatmap: Bool) {
        self.nspc = samplesPerChain
        self.isc = initSamplesCount
        self.integrator = integrator
        self.heatmap = heatmap ? Heatmap(floor: Color(0, 0, 1), ceil: Color(1, 1, 0)) : nil
        self.stats = (.init(times: 0, accept: 0, reject: 0), .init(times: 0, accept: 0, reject: 0))
    }

    func preprocess(scene: Scene, sampler: any Sampler) {
        let (b, cdf, seeds) = normalizationConstant(scene: scene, sampler: sampler)
        self.b = b
        self.cdf = cdf
        self.seeds = seeds
    }

    func render(scene: Scene, sampler: any Sampler) -> PixelBuffer {
        self.nspp = sampler.nbSamples
        let totalSamples = nspp * Int(scene.camera.resolution.x) * Int(scene.camera.resolution.y)
        let nbChains = totalSamples / nspc
        
        print("Rendering pssmlt with \(integrator)")
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
        //let average = image.total / Float(image.size)
        let average = image.reduce(into: .zero) { acc, cur in
            acc += cur.sanitized.luminance
        } / Float(image.size)
        
        print("largeStepCount => \(stats.large.times)")
        print("smallStepCount => \(stats.small.times)")
        print("smallStepAcceptRatio => \(Float(stats.small.accept) / Float(stats.small.accept + stats.small.reject))")
        print("largeStepAcceptRatio => \(Float(stats.large.accept) / Float(stats.large.accept + stats.large.reject))")
        print("average => \(average)")
        print("b => \(b)")

        image.scale(by: b / average)
        
        if let img = heatmap?.generate(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y)) {
            _ = Image(encoding: .png).write(img: img, to: "\(identifier)_heatmap.png")
        }
        return image
    }
    
    /// Computes the normalization factor
    private func normalizationConstant(scene: Scene, sampler: Sampler) -> (Float, DistributionOneDimention, [(Float, UInt64)]) {
        var seeds: [(Float, UInt64)] = []
        var totalValid = isc
        let b = (0 ..< isc).map { _ in
            let currentSeed = sampler.rng.state
            
            let s = sample(scene: scene, sampler: sampler)
            let validSample = s.targetFunction.isFinite && !s.targetFunction.isNaN && !s.targetFunction.isZero
            if validSample {
                seeds.append((s.targetFunction, currentSeed))
            } else {
                totalValid -= 1
            }

            return validSample ? s.targetFunction : 0
        }.reduce(0, +) / Float(isc)
        
        guard b.isFinite, !b.isNaN, !b.isZero else { fatalError("Invalid computation of b") }
        var cdf = DistributionOneDimention(count: seeds.count)
        for s in seeds {
            cdf.add(s.0)
        }
        
        print("Seeds count => \(seeds.count)")
        cdf.normalize()
        return (b, cdf, seeds)
    }
    
    private func sample(scene: Scene, sampler: Sampler) -> StateMCMC {
        let rng2 = sampler.next2()
        let x = min(scene.camera.resolution.x * rng2.x, scene.camera.resolution.x - 1)
        let y = min(scene.camera.resolution.y * rng2.y, scene.camera.resolution.y - 1)
        let contrib = integrator.li(pixel: Vec2(Float(x), Float(y)), scene: scene, sampler: sampler)
        return StateMCMC(contrib: contrib, pos: Vec2(Float(x), Float(y)))
    }

    /// Create the async blocks responsible for rendering with a Markov Chain
    private func chains(samples: Int, nbChains: Int, seeds: [(Float, UInt64)], cdf: DistributionOneDimention, scene: Scene, increment: @escaping () -> Void) async -> PixelBuffer {
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
    
    /// Random walk rendering of MCMC
    private func renderChain(i: Int, total: Int, seeds: [(Float, UInt64)], cdf: DistributionOneDimention, scene: Scene, into image: PixelBuffer) -> Void {
        let id = (Float(i) + 0.5) / Float(total)
        let i = cdf.sampleDiscrete(id)
        let seed = seeds[i]
        let sampler = PSSMLTSampler(nbSamples: nspp)
        let previousSeed = sampler.rng.state
        sampler.rng.state = seed.1
        
        let chain = MarkovChain(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y))
        sampler.step = .large
        
        var state = self.sample(scene: scene, sampler: sampler)
        guard state.targetFunction == seed.0 else { fatalError("Inconsistent seed-sample") }
        sampler.accept()
        
        sampler.rng.state = previousSeed
        
        for _ in 0 ..< self.nspc {
            sampler.step = Float.random(in: 0 ... 1) < sampler.largeStepRatio
                ? .large
                : .small
            
            var proposedState = self.sample(scene: scene, sampler: sampler)
            let acceptProbability = proposedState.targetFunction < 0 || proposedState.contrib.hasNaN
                ? 0
                : min(1.0, proposedState.targetFunction / state.targetFunction)
            
            // This is veach style expectations; See if using Kelemen style wouldn't be more appropriate
            state.weight += 1.0 - acceptProbability
            proposedState.weight += acceptProbability
            
            if acceptProbability == 1 || acceptProbability > Float.random(in: 0 ... 1) {
                chain.add(state: &state, heatmap: &heatmap)
                sampler.accept()
                state = proposedState
            } else {
                chain.add(state: &proposedState, heatmap: &heatmap)
                sampler.reject()
            }
        }
        
        // Flush the last state
        chain.add(state: &state, heatmap: &heatmap)
        chain.img.scale(by: 1.0 / Float(nspc))
        image.merge(with: chain.img)
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

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
    }
    
    internal struct StateMCMC {
        var pos: Vec2
        var contrib: Color
        var weight: Float = 0
        var targetFunction: Float = 0
        
        init(contrib: Color, pos: Vec2) {
            self.contrib = contrib
            self.pos = pos
            self.targetFunction = (contrib.x + contrib.y + contrib.z) / 3
        }
    }

    private class MarkovChain {
        private(set) var img: Array2d<Color>
        
        init(x: Int, y: Int) {
            img = Array2d(x: x, y: y, value: Color())
        }

        func add(state: inout StateMCMC) {
            let w = state.targetFunction == 0
                ? 0
                : state.weight / state.targetFunction
            let x = Int(state.pos.x)
            let y = Int(state.pos.y)
            img.add(value: state.contrib * w, x, y)
            state.weight = 0
        }
    }

    // TODO Allow to plug and play this thing
    private let integrator: SamplerIntegrator
    /// Samples Per Chain
    private let nspc: Int
    /// Initialization Samples Count
    private let isc: Int
    /// Samples per pixel (can derive total sample from this).
    private var nspp: Int = 10

    private var result: Array2d<Color>?
    private var stats: (small: PSSMLTSampler.Stats, large: PSSMLTSampler.Stats)

    init(samplesPerChain: Int, initSamplesCount: Int, integrator: SamplerIntegrator) {
        self.nspc = samplesPerChain
        self.isc = initSamplesCount
        self.integrator = integrator
        self.stats = (.init(times: 0, accept: 0, reject: 0), .init(times: 0, accept: 0, reject: 0))
    }

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        self.nspp = sampler.nbSamples
        let (b, cdf, seeds) = normalizationConstant(scene: scene, sampler: sampler)
        let totalSamples = sampler.nbSamples * Int(scene.camera.resolution.x) * Int(scene.camera.resolution.y)
        let nbChains = totalSamples / nspc
        
        let beforeBlackCount = zeroColorFound
        // Run chains in parallel
        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: nbChains, printer: Printer())
            let img = await chains(samples: totalSamples, nbChains: nbChains, seeds: seeds, cdf: cdf, integrator: integrator, scene: scene) {
                progress.next()
            }
            self.result = img
        }
        gcd.wait()
        
        guard let image = result else { fatalError("No result image was returned in the async task") }
        //let average = image.total / Float(image.size)
        let average = image.reduce(into: Color()) { acc, cur in
            acc += cur.sanitized / Float(image.size)
        }
        let averageLuminance = (average.x + average.y + average.z) / 3.0
        
        print("Nb of black pixels found in chains => \(zeroColorFound - beforeBlackCount)")
        print("largeStepCount => \(stats.large.times)")
        print("smallStepCount => \(stats.small.times)")
        print("smallStepAcceptRatio => \(Float(stats.small.accept) / Float(stats.small.accept + stats.small.reject))")
        print("largeStepAcceptRatio => \(Float(stats.large.accept) / Float(stats.large.accept + stats.large.reject))")
        print("average => \(average)")
        print("average luminance => \(averageLuminance)")
        print("b => \(b)")

        image.scale(by: b / averageLuminance)
        return image
    }
    
    /// Computes the normalization factor
    private func normalizationConstant(scene: Scene, sampler: Sampler) -> (Float, DistributionOneDimention, [(Float, UInt64)]) {
        var seeds: [(Float, UInt64)] = []
        let b = (0 ..< isc).map { _ in
            let currentSeed = sampler.rng.state
            
            let s = sample(scene: scene, sampler: sampler)
            if s.targetFunction > 0 {
                seeds.append((s.targetFunction, currentSeed))
            }

            return s.targetFunction
        }.reduce(0, +) / Float(isc)
        
        guard b != 0 else { fatalError("Invalid computation of b") }
        var cdf = DistributionOneDimention(count: seeds.count)
        for s in seeds {
            cdf.add(s.0)
        }
        
        print("Seeds count => \(seeds.count)")
        cdf.normalize()
        return (b, cdf, seeds)
    }
    
    private var zeroColorFound: Int = 0
    
    private func sample(scene: Scene, sampler: Sampler) -> StateMCMC {
        let rng2 = sampler.next2()
        let x = Int(min(scene.camera.resolution.x * rng2.x, scene.camera.resolution.x - 1))
        let y = Int(min(scene.camera.resolution.y * rng2.y, scene.camera.resolution.y - 1))
        let contrib = integrator.render(pixel: Vec2(Float(x), Float(y)) + sampler.next2(), scene: scene, sampler: sampler)
        if !contrib.hasColor { zeroColorFound += 1 }
        return StateMCMC(contrib: contrib, pos: Vec2(Float(x), Float(y)))
    }

    /// Create the async blocks responsible for rendering with a Markov Chain
    private func chains(samples: Int, nbChains: Int, seeds: [(Float, UInt64)], cdf: DistributionOneDimention, integrator: SamplerIntegrator, scene: Scene, increment: @escaping () -> Void) async -> Array2d<Color> {
        return await withTaskGroup(of: Void.self, returning: Array2d<Color>.self) { group in
            let image = Array2d(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: Color())
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
    private func renderChain(i: Int, total: Int, seeds: [(Float, UInt64)], cdf: DistributionOneDimention, scene: Scene, into image: Array2d<Color>) -> Void {
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
                chain.add(state: &state)
                sampler.accept()
                state = proposedState
            } else {
                chain.add(state: &proposedState)
                sampler.reject()
            }
        }
        
        // Flush the last state
        chain.add(state: &state)
        chain.img.scale(by: 1.0 / Float(nspc))
        image.merge(with: chain.img)
        stats.small.combine(with: sampler.smallStats)
        stats.large.combine(with: sampler.largeStats)
    }
}

private extension Array2d<Color> {
    // TODO Move into Array2d by fixing generic constraints
    func scale(by factor: Float) {
        for (i, item) in self.enumerated() {
            let (x, y) = index2d(i)
            set(value: item * factor, x, y)
        }
    }
}

private extension PSSMLTSampler.Stats {
    mutating func combine(with other: Self) {
        self.times += other.times
        self.accept += other.accept
        self.reject += other.reject
    }
}

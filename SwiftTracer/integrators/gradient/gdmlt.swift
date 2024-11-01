//
//  gdmlt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-18.
//

import Foundation
import Progress

final class GdmltIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case shiftMapping
        case samplesPerChain
        case initSamplesCount
        case reconstruction
    }

    internal struct StateMCMC {
        var pos: Vec2
        var offset: Vec2
        var contrib: Color
        var shiftContrib: Color
        var weight: Float = 0
        var targetFunction: Float = 0
        let delta: Color

        init(contrib: Color, pos: Vec2, offset: Vec2, shiftContrib: Color, gradient: Color, alpha: Float = 0.3) {
            self.contrib = contrib
            self.pos = pos
            self.offset = offset
            self.shiftContrib = shiftContrib
            
            let forward = offset.sum() > 0
            self.delta = if forward { gradient } else { gradient * -1 }
            
            let luminance = (contrib.x + contrib.y + contrib.z) / 3
            let shiftedLuminance = (shiftContrib.x + shiftContrib.y + shiftContrib.z) / 3
            self.targetFunction = shiftedLuminance.abs() + alpha * (0.25 * luminance).abs()
        }
    }
    
    private class MarkovChain {
        private(set) var img: Array2d<Color>
        private(set) var dx: Array2d<Color>
        private(set) var dy: Array2d<Color>
        
        init(x: Int, y: Int) {
            self.img = Array2d(x: x, y: y, value: .zero)
            self.dx = Array2d(x: x, y: y, value: .zero)
            self.dy = Array2d(x: x, y: y, value: .zero)
        }

        // TODO Rework this
        func add(state: inout StateMCMC) {
            let w = state.targetFunction == 0
                ? 0
                : state.weight / state.targetFunction
            let x = Int(state.pos.x)
            let y = Int(state.pos.y)
            img[x, y] += state.contrib * w
            
            state.weight = 0
            
            let x2 = Int(state.pos.x + state.offset.x)
            let y2 = Int(state.pos.y + state.offset.y)
            switch state.offset {
            case Vec2(1, 0),  Vec2(-1, 0):
                guard (0 ..< dx.xSize).contains(x2) && (0 ..< dx.ySize).contains(y2) else { return }
                dx[x2, y2] += state.delta * w
            case Vec2(0, 1), Vec2(0, -1):
                guard (0 ..< dy.xSize).contains(x2) && (0 ..< dy.ySize).contains(y2) else { return }
                dy[x2, y2] += state.delta * w
            default:
                fatalError("Invalid shift")
            }
        }
    }
    
    /// Samples Per Chain
    private let nspc: Int
    /// Initialization Samples Count
    private let isc: Int
    /// Samples per pixel (can derive total sample from this).
    private var nspp: Int = 10

    private var result: GradientDomainResult?

    private let integrator: SamplerIntegrator
    private let reconstructor: Reconstructing
    private let mapper: any ShiftMapping
    private let shiftCdf: DistributionOneDimention
    private let shifts: [Vec2] = [Vec2(0, 1), Vec2(1, 0), Vec2(0, -1), Vec2(-1, 0)]
    
    init(mapper: ShiftMapping, reconstructor: Reconstructing, samplesPerChain: Int, initSamplesCount: Int) {
        self.mapper = mapper
        self.integrator = PathIntegrator(minDepth: 0, maxDepth: 16)
        self.reconstructor = reconstructor
        let n = 4
        var cdf = DistributionOneDimention(count: n)
        for _ in 0 ..< n {
            cdf.add(0.25)
        }
        cdf.normalize()
        self.shiftCdf = cdf
        
        self.nspc = samplesPerChain
        self.isc = initSamplesCount
    }

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let result: GradientDomainResult = render(scene: scene, sampler: sampler)
        return result.img
    }
    
    func sample(scene: Scene, sampler: Sampler) -> StateMCMC {
        let rng2 = sampler.next2()

        let id = shiftCdf.sampleDiscrete(sampler.next())
        let x = min(scene.camera.resolution.x * rng2.x, scene.camera.resolution.x - 1)
        let y = min(scene.camera.resolution.y * rng2.y, scene.camera.resolution.y - 1)
        let pixel = Vec2(Float(x), Float(y))
        let result = mapper.shift(pixel: pixel, sampler: sampler, params: ShiftMappingParams(offsets: [shifts[id]]))

        //if !contrib.hasColor { zeroColorFound += 1 }
        return StateMCMC(
            contrib: result.main,
            pos: pixel,
            offset: shifts[id],
            shiftContrib: result.radiances[id],
            gradient: result.gradients[id]
        )
    }
}

extension GdmltIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: any Sampler) {
        mapper.initialize(scene: scene)
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
        print("Integrator preprocessing ...")
        preprocess(scene: scene, sampler: sampler)

        self.nspp = sampler.nbSamples
        
        let (b, cdf, seeds) = normalizationConstant(scene: scene, sampler: sampler)
        let totalSamples = nspp * Int(scene.camera.resolution.x) * Int(scene.camera.resolution.y)
        let nbChains = totalSamples / nspc
        
        print("Rendering ...")
        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: nbChains, printer: Printer())
            let result = await chains(samples: totalSamples, nbChains: nbChains, seeds: seeds, cdf: cdf, scene: scene) { progress.next() }
            self.result = result
        }
        gcd.wait()
        
        guard let result = result else { fatalError("No result image was returned in the async task") }
        let average = result.img.reduce(into: .zero) { acc, cur in
            acc += cur.sanitized / Float(result.img.size)
        }
        let averageLuminance = (average.x + average.y + average.z) / 3.0
        
        // TODO Print stats
        // TODO Scale contents of images
        print("Reconstructing with dx and dy ...")
        result.img.scale(by: b / averageLuminance)
        let reconstruction = reconstructor.reconstruct(image: result.img, dx: result.dx, dy: result.dy)
        
        return GradientDomainResult(
            primal: result.img,
            img: reconstruction,
            dx: result.dx.transformed { $0.abs },
            dy: result.dy.transformed { $0.abs }
        )
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
    
    private func chains(samples: Int, nbChains: Int, seeds: [(Float, UInt64)], cdf: DistributionOneDimention, scene: Scene, increment: @escaping () -> Void) async -> GradientDomainResult {
        return await withTaskGroup(of: Void.self, returning: GradientDomainResult.self) { group in
            let img = Array2d<Color>(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: .zero)
            let dx = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
            let dy = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
            var result = GradientDomainResult(primal: img, img: img, dx: dx, dy: dy)
            var processed = 0
            for i in 0 ..< nbChains {
                group.addTask {
                    increment()
                    return self.renderChain(i: i, total: nbChains, seeds: seeds, cdf: cdf, scene: scene, into: &result)
                }
            }
            
            for await _ in group {
                processed += 1
            }
            
            return result
        }
    }
    
    private func renderChain(i: Int, total: Int, seeds: [(Float, UInt64)], cdf: DistributionOneDimention, scene: Scene, into acc: inout GradientDomainResult) -> Void {
        let id = (Float(i) + 0.5) / Float(total)
        let i = cdf.sampleDiscrete(id)
        let seed = seeds[i]
        let sampler = PSSMLTSampler(nbSamples: nspp)
        let previousSeed = sampler.rng.state
        sampler.rng.state = seed.1
        
        // Reinitialize with appropriate sampler
        let chain = MarkovChain(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y))
        sampler.step = .large
        
        var state = self.sample(scene: scene, sampler: sampler)
        guard state.targetFunction == seed.0 else { fatalError("Inconsistent seed-sample") }
        sampler.accept()

        sampler.rng.state = previousSeed
        
        for _ in 0 ..< nspc {
            sampler.step = Float.random(in: 0 ... 1) < sampler.largeStepRatio
                ? .large
                : .small
            
            var proposedState = self.sample(scene: scene, sampler: sampler)
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
        
        let scale = 1 / Float(nspc)
        chain.add(state: &state)
        chain.img.scale(by: scale)
        chain.dx.scale(by: scale)
        chain.dy.scale(by: scale)
        acc.img.merge(with: chain.img)
        acc.dx.merge(with: chain.dx)
        acc.dy.merge(with: chain.dy)
//            print("Chain \(i )step \(n)")
    }
}

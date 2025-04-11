//
//  gdmala.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2025-02-06.
//

import Collections
import Foundation
import Progress

final class GdmalaIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case shiftMapping
        case samplesPerChain
        case initSamplesCount
        case reconstruction
        case step
        case targetFunction
        case kernel
        case normalization
        case maxDepth
    }
    
    enum TargetFunction: String, Decodable {
        case gradient
        case luminance
    }
    
    enum Kernel: String, Decodable {
        case simple
        case shifted
    }
    
    struct KernelGradientState {
        let contrib: Color
        let contribPrime: Color
        let pos: Vec2
        let u: Vec2
        let gradient: Vec2
        var weight: Float = 0
        var targetFunction: Float = 0
        let shiftContrib: [Color]
        let directLight: Color
        let delta: [Color]
        let offsets: OrderedSet = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]
        var acceptanceTerm: Vec2 = .zero
        
        init(contrib: Color, contribPrime: Color, pos: Vec2, directLight: Color, shiftContribs: [Color], gradients: [Color], alpha: Float = 0.2, target: TargetFunction, u: Vec2, gradient: Vec2, acceptanceTerm: Vec2) {
            self.u = u
            self.gradient = gradient
            if contrib.luminance > 100 {
                self.contrib = contrib / contrib.luminance
            } else {
                self.contrib = contrib
            }
            if contribPrime.luminance > 100 {
                self.contribPrime = (contribPrime / contribPrime.luminance) + directLight
            } else {
                self.contribPrime = contribPrime + directLight
            }
            self.pos = pos
            self.shiftContrib = shiftContribs.map {
                if $0.luminance > 100 { $0 / $0.luminance } else { $0 }
            }
            self.directLight = directLight
            let offsets = self.offsets // Weird quirk about accessing self.delta
            self.delta = gradients.enumerated().map({ (i, gradient) in
                let forward = offsets[i].sum() > 0
                return if forward { gradient } else { gradient * -1 }
            })

            let gradientLuminance: Float = offsets.enumerated().reduce(into: 0) { (acc, pair) in
                let (i, _) = pair
                acc += delta[i].abs.luminance
            }
            
            let luminance = self.contrib.abs.luminance + directLight.abs.luminance
            self.targetFunction = switch target {
                case .gradient: gradientLuminance + alpha * 0.25 * luminance
                case .luminance: luminance
            }
            self.acceptanceTerm = acceptanceTerm
        }
    }
    
    private class MarkovChain {
        private(set) var img: PixelBuffer
        private(set) var dx: PixelBuffer
        private(set) var dy: PixelBuffer
        private(set) var directLight: PixelBuffer
        
        init(blank: PixelBuffer) {
            self.img = PixelBuffer(copy: blank)
            self.dx = PixelBuffer(copy: blank)
            self.dy = PixelBuffer(copy: blank)
            self.directLight = PixelBuffer(copy: blank)
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
    
    let identifier = "gdmala"
    let mapper: any ShiftMapping
    
    /// Samples Per Chain
    private let nspc: Int
    /// Initialization Samples Count
    private let isc: Int
    /// Samples per pixel (can derive total sample from this).
    private var nspp: Int = 10
    private let step: Float
    private let maxDepth: Int

    private var result: GradientDomainResult?
    private let reconstructor: Reconstructing
    private let targetFunction: TargetFunction
    private let kernel: Kernel
    
    private let shifts: [Vec2] = [Vec2(0, 1), Vec2(1, 0), Vec2(0, -1), Vec2(-1, 0)]
    
    private var b: Float
    private var cdf = DistributionOneDimention(count: 0)
    private var seeds: [StartupSeed] = []
    
    private var stats: (small: PSSMLTSampler.Stats, large: PSSMLTSampler.Stats)
    private var blankBuffer: PixelBuffer!
    
    init(mapper: ShiftMapping, reconstructor: Reconstructing, samplesPerChain: Int, initSamplesCount: Int, step: Float, targetFunction: TargetFunction, kernel: Kernel, normalization: Float?, maxDepth: Int) {
        self.mapper = mapper
        self.reconstructor = reconstructor
        self.nspc = samplesPerChain
        self.isc = initSamplesCount
        self.step = step
        self.stats = (.init(times: 0, accept: 0, reject: 0), .init(times: 0, accept: 0, reject: 0))
        self.targetFunction = targetFunction
        self.kernel = kernel
        self.maxDepth = maxDepth
        self.b = normalization ?? 0
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
    
    private func sample(scene: Scene, sampler: Sampler, mapper: ShiftMapping) -> KernelGradientState {
        let rng2 = sampler.next2()

        let x = min(scene.camera.resolution.x * rng2.x, scene.camera.resolution.x - 1)
        let y = min(scene.camera.resolution.y * rng2.y, scene.camera.resolution.y - 1)
        let pixel = Vec2(Float(x), Float(y))
        
        let replaySampler = ReplaySampler(sampler: sampler, random: [])
        let result = mapper.shift(pixel: pixel, sampler: replaySampler, params: ShiftMappingParams(offsets: nil, maxDepth: maxDepth))
        let dx: Float
        let dy: Float
        if kernel == .shifted {
            let kernelTargets: [Float] = self.shifts.map {
                let kernelSampler = ReplaySampler(sampler: sampler, random: replaySampler.random)
                let kernelResult = mapper.shift(pixel: pixel + $0, sampler: kernelSampler, params: ShiftMappingParams(offsets: nil, maxDepth: maxDepth))
                let kernelState = KernelGradientState(
                    contrib: kernelResult.main,
                    contribPrime: kernelResult.mainPrime,
                    pos: pixel,
                    directLight: kernelResult.directLight,
                    shiftContribs: kernelResult.radiances,
                    gradients: kernelResult.gradients,
                    target: targetFunction,
                    u: rng2,
                    gradient: .zero,
                    acceptanceTerm: .zero
                )
                return kernelState.targetFunction
            }
            
            dx = (kernelTargets[1] - kernelTargets[0]) * 0.5
            dy = (kernelTargets[3] - kernelTargets[2]) * 0.5
        } else {
            dx = (result.radiances[1] - result.radiances[0]).luminance * 0.5
            dy = (result.radiances[3] - result.radiances[2]).luminance * 0.5
        }
        let gradient = Vec2(dx, dy)
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
        return KernelGradientState(
            contrib: result.main,
            contribPrime: result.mainPrime,
            pos: pixel,
            directLight: result.directLight,
            shiftContribs: result.radiances,
            gradients: result.gradients,
            target: targetFunction,
            u: rng2,
            gradient: gradient,
            acceptanceTerm: acceptanceTerm
        )
    }
}

extension GdmalaIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: any Sampler) {
        mapper.initialize(scene: scene)
        let (b, cdf, seeds) = normalizationConstant(scene: scene, sampler: sampler)
        // If no normalization constant was provided, use the one calculated here
        if self.b == 0 {
            self.b = b
        }
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
        self.nspp = sampler.nbSamples
        let x = Int(scene.camera.resolution.x)
        let y = Int(scene.camera.resolution.y)
        let totalSamples = nspp * x * y
        let nbChains = totalSamples / nspc
        self.blankBuffer = PixelBuffer(width: x, height: y, value: .zero)
        
        print("GDMala Rendering with \(mapper.identifier), \(targetFunction.rawValue) TF and \(kernel.rawValue) kernel...")
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
        
        let average = result.primal.reduce(into: .zero) { acc, cur in
            acc += cur.sanitized.luminance
        } / Float(result.primal.size)
        let directAverage = result.directLight.reduce(into: .zero) { acc, cur in
            acc += cur.sanitized.luminance
        } / Float(result.primal.size)
        let combinedAvg = average + directAverage
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
        let chain = MarkovChain(blank: blankBuffer)
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
                : acceptance(u: state, v: proposedState)
            
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
    
    // q(u|v)
    private func transitionProbDensity(u: KernelGradientState, v: KernelGradientState) -> Float {
        let q = -(u.u - v.u - v.acceptanceTerm).lengthSquared / (4 * step)
        return exp(q)
    }
    
    // a = min(1, π(v) q(u|v) / π(u) q(v|u))
    private func acceptance(u: KernelGradientState, v: KernelGradientState) -> Float {
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

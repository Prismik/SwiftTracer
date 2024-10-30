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

        init(contrib: Color, pos: Vec2, offset: Vec2, shiftContrib: Color, alpha: Float = 0.3) {
            self.contrib = contrib
            self.pos = pos
            self.offset = offset
            
            self.shiftContrib = shiftContrib
            
            let delta: Color
            switch offset {
            case Vec2(1, 0), Vec2(0, 1):
                delta = shiftContrib - contrib
            case Vec2(-1, 0), Vec2(0, -1):
                delta = contrib - shiftContrib
            default:
                fatalError("Invalid shift")
            }
            
            self.delta = delta
            
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
            
            let x2 = Int(state.pos.x + state.offset.x)
            let y2 = Int(state.pos.y + state.offset.y)
            switch state.offset {
            case Vec2(1, 0):
                dx[x2, y2] += (state.shiftContrib - state.contrib) * w
            case Vec2(-1, 0):
                dx[x2, y2] += (state.contrib - state.shiftContrib) * w
            case Vec2(0, 1):
                dy[x2, y2] += (state.shiftContrib - state.contrib) * w
            case Vec2(0, -1):
                dy[x2, y2] += (state.contrib - state.shiftContrib) * w
            default:
                fatalError("Invalid shift")
            }
            state.weight = 0
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
    private let mapper: ShiftMapping
    private let shiftCdf: DistributionOneDimention
    private let shifts: [Vec2] = [Vec2(0, 1), Vec2(1, 0), Vec2(0, -1), Vec2(-1, 0)]
    
    init(mapper: ShiftMapping, reconstructor: Reconstructing, samplesPerChain: Int, initSamplesCount: Int) {
        self.mapper = mapper
        self.integrator = PathIntegrator(minDepth: 0, maxDepth: 16)
        self.reconstructor = reconstructor
        let n = 4
        var cdf = DistributionOneDimention(count: n)
        for i in 0 ..< n {
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
        let shift = shifts[id]

        let x = min(scene.camera.resolution.x * rng2.x, scene.camera.resolution.x - 1)
        let y = min(scene.camera.resolution.y * rng2.y, scene.camera.resolution.y - 1)
        let contrib = integrator.li(pixel: Vec2(Float(x), Float(y)), scene: scene, sampler: sampler)
        let shiftContrib = integrator.li(pixel: Vec2(Float(x), Float(y)) + shift, scene: scene, sampler: sampler)

        //if !contrib.hasColor { zeroColorFound += 1 }
        return StateMCMC(
            contrib: contrib,
            pos: Vec2(Float(x), Float(y)),
            offset: shift,
            shiftContrib: shiftContrib
        )
    }
}

extension GdmltIntegrator: GradientDomainIntegrator {
    func render(scene: Scene, sampler: any Sampler) -> GradientDomainResult {
        self.nspp = sampler.nbSamples
        
        // TODO compute normalization constant b
        
        let totalSamples = nspp * Int(scene.camera.resolution.x) * Int(scene.camera.resolution.y)
        let nbChains = totalSamples / nspc
        
        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: nbChains, printer: Printer())
            let img = Array2d<Color>(x: 0, y: 0, value: .zero)
            self.result = GradientDomainResult(img: img, dx: img, dy: img)
        }
        gcd.wait()
        
        guard let result = result else { fatalError("No result image was returned in the async task") }
        
        // TODO Print stats
        // TODO Scale contents of images
    
        let reconstruction = reconstructor.reconstruct(image: result.img, dx: result.dx, dy: result.dy)
        
        return GradientDomainResult(
            img: reconstruction,
            dx: result.dx.transformed { $0.abs },
            dy: result.dy.transformed { $0.abs }
        )
    }
    
    private func chains(samples: Int, nbChains: Int, scene: Scene, increment: @escaping () -> Void) async -> GradientDomainResult {
        return await withTaskGroup(of: Void.self, returning: GradientDomainResult.self) { group in
            let img = Array2d<Color>(x: 0, y: 0, value: .zero)
            var result = GradientDomainResult(img: img, dx: img, dy: img)
            var processed = 0
            for i in 0 ..< nbChains {
                group.addTask {
                    increment()
                    return self.renderChain(i: i, total: nbChains, scene: scene, into: &result)
                }
            }
            
            for await _ in group {
                processed += 1
            }
            
            return result
        }
        
    }
    
    private func renderChain(i: Int, total: Int, scene: Scene, into acc: inout GradientDomainResult) -> Void {
        // TODO Make the actual rendering of a chain here
        let sampler = PSSMLTSampler(nbSamples: nspp)
        
        let chain = MarkovChain(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y))
        
        var state = self.sample(scene: scene, sampler: sampler)
        
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
            
            let scale = 1 / Float(nspc)
            chain.add(state: &state)
            chain.img.scale(by: scale)
            chain.dx.scale(by: scale)
            chain.dy.scale(by: scale)
            acc.img.merge(with: chain.img)
            acc.dx.merge(with: chain.dx)
            acc.dy.merge(with: chain.dy)
            
            
        }
    }
}

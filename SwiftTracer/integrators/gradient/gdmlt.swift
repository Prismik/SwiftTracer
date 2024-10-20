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
                // impossible
                delta = .zero
            }
            
            self.delta = delta
            
            let luminance = (contrib.x + contrib.y + contrib.z) / 3
            let shiftedLuminance = (shiftContrib.x + shiftContrib.y + shiftContrib.z) / 3
            self.targetFunction = shiftedLuminance.abs() + alpha * (0.25 * luminance).abs()
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
    private let mapper: ShiftMapping
    private let shiftCdf: DistributionOneDimention
    private let shifts: [Vec2] = [Vec2(0, 1), Vec2(1, 0), Vec2(0, -1), Vec2(-1, 0)]
    
    init(mapper: ShiftMapping, samplesPerChain: Int, initSamplesCount: Int) {
        self.mapper = mapper
        integrator = PathIntegrator(minDepth: 0, maxDepth: 16)
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
        
        guard let images = result else { fatalError("No result image was returned in the async task") }
        
        // TODO Print stats
        // TODO Scale contents of images
    
        return images
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
    
    private func renderChain(i: Int, total: Int, scene: Scene, into: inout GradientDomainResult) -> Void {
        // TODO Make the actual rendering of a chain here
    }
    
    // TODO Make a combine function for GradientDomain Result
}

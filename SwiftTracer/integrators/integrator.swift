//
//  integrator.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-18.
//

import Foundation
import Progress

enum IntegratorType: String, Decodable {
    case path
    case normal
    case uv
    case direct
    case pssmlt
    case gdmlt
    case gdpt
}

/// Integrating one pixel at a time.
protocol SamplerIntegrator: AnyObject {
    func preprocess(scene: Scene, sampler: Sampler)
    /// Estimate the incoming light for a given ray
    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color
    func li(pixel: Vec2, scene: Scene, sampler: Sampler) -> Color
}

struct GradientDomainResult {
    let img: Array2d<Color>
    let dx: Array2d<Color>
    let dy: Array2d<Color>
}

/// Integraeting in using gradients of the image plane.
protocol GradientDomainIntegrator {
    func render(scene: Scene, sampler: Sampler) -> GradientDomainResult
}

protocol Integrator {
    func render(scene: Scene, sampler: Sampler) -> Array2d<Color>
}

/// Box type for ``Integrator`` protocol that allows to decode integrators in a type agnostic way.
struct AnyIntegrator: Decodable {
    enum CodingKeys: String, CodingKey {
        case type
        case params
    }
    
    let wrapped: Integrator

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(IntegratorType.self, forKey: .type)
        switch type {
        case .path:
            let params = try container.nestedContainer(keyedBy: PathIntegrator.CodingKeys.self, forKey: .params)
            let minDepth = try params.decodeIfPresent(Int.self, forKey: .minDepth) ?? 0
            let maxDepth = try params.decodeIfPresent(Int.self, forKey: .maxDepth) ?? 16
            let mis = try params.decode(Bool.self, forKey: .mis)
            self.wrapped = PathIntegrator(minDepth: minDepth, maxDepth: maxDepth, mis: mis)
        case .direct:
            let params = try container.nestedContainer(keyedBy: DirectIntegrator.CodingKeys.self, forKey: .params)
            let strategy = try params.decode(DirectIntegrator.Strategy.self, forKey: .strategy)
            self.wrapped = DirectIntegrator(strategy: strategy)
        case .normal:
            self.wrapped = NormalIntegrator()
        case .uv:
            self.wrapped = UvIntegrator()
        case .pssmlt:
            let params = try container.nestedContainer(keyedBy: PssmltIntegrator.CodingKeys.self, forKey: .params)
            let spc = try params.decode(Int.self, forKey: .samplesPerChain)
            let isc = try params.decode(Int.self, forKey: .initSamplesCount)
            let integrator = (try? params.decode(AnyIntegrator.self, forKey: .integrator))?.wrapped as? SamplerIntegrator
            
            self.wrapped = PssmltIntegrator(
                samplesPerChain: spc,
                initSamplesCount: isc,
                integrator: integrator ?? PathIntegrator(minDepth: 0, maxDepth: 16)
            )
        case .gdpt:
            let params = try container.nestedContainer(keyedBy: GdptIntegrator.CodingKeys.self, forKey: .params)
            let anyShiftMapping = try params.decode(AnyShiftMappingOperator.self, forKey: .shiftMapping)
            let reconstructor = try params.decode(AnyReconstruction.self, forKey: .reconstruction)
            self.wrapped = GdptIntegrator(mapper: anyShiftMapping.wrapped, reconstructor: reconstructor.wrapped, maxReconstructIterations: 40)
        case .gdmlt:
            let params = try container.nestedContainer(keyedBy: GdmltIntegrator.CodingKeys.self, forKey: .params)
            let anyShiftMapping = try params.decode(AnyShiftMappingOperator.self, forKey: .shiftMapping)
            let spc = try params.decode(Int.self, forKey: .samplesPerChain)
            let isc = try params.decode(Int.self, forKey: .initSamplesCount)
            let reconstructor = try params.decode(AnyReconstruction.self, forKey: .reconstruction)
            self.wrapped = GdmltIntegrator(mapper: anyShiftMapping.wrapped, reconstructor: reconstructor.wrapped, samplesPerChain: spc, initSamplesCount: isc)
        }
    }
}

struct Printer: ProgressBarPrinter {
    var lastPrintedTime = 0.0

    init() {
        // the cursor is moved up before printing the progress bar.
        // have to move the cursor down one line initially.
        print("")
    }
    
    mutating func display(_ progressBar: ProgressBar) {
        var tv = timeval()
        gettimeofday(&tv, nil)
        let currentTime = Double(tv.tv_sec) + Double(tv.tv_usec) / 1000000
        if (currentTime - lastPrintedTime > 0.1 || progressBar.index == progressBar.count) {
            print(progressBar.value)
            lastPrintedTime = currentTime
        }
    }
}

enum MonteCarloIntegrator {
    internal struct Block {
        let position: Vec2
        let size: Vec2
        let sample: Sampler
        var image: Array2d<Color>
        var intersectionCount: Int
        var rayCount: Int
        
        var images: [Array2d<Color>] { [image] }
    }

    static func render<T: SamplerIntegrator>(integrator: T, scene: Scene, sampler: Sampler) -> Array2d<Color> {
        print("Integrator preprocessing ...")
        integrator.preprocess(scene: scene, sampler: sampler)
        
        print("Rendering with \(integrator) ...")
        let image = Array2d(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: Color())
        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: Int(scene.camera.resolution.x) / 32 * Int(scene.camera.resolution.y) / 32, printer: Printer())
            let blocks = await renderBlocks(blockSize: 32, scene: scene, integrator: integrator, sampler: sampler) {
                progress.next()
            }
            return blocks.assemble(into: image)
        }
        
        gcd.wait()
        return image
    }
    
    private static func renderBlocks(blockSize: Int = 32, scene: Scene, integrator: SamplerIntegrator, sampler: Sampler, increment: @escaping () -> Void) async -> [Block] {
        return await withTaskGroup(of: Block.self) { group in
            for x in stride(from: 0, to: Int(scene.camera.resolution.x), by: blockSize) {
                for y in stride(from: 0, to: Int(scene.camera.resolution.y), by: blockSize) {
                    let size = Vec2(
                        min(scene.camera.resolution.x - Float(x), Float(blockSize)),
                        min(scene.camera.resolution.y - Float(y), Float(blockSize))
                    )
                    
                    group.addTask {
                        increment()
                        return renderMonteCarlo(scene: scene, integrator: integrator, size: size, x: x, y: y, sampler: sampler)
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
    
    private static func renderMonteCarlo(scene: Scene, integrator: SamplerIntegrator, size: Vec2, x: Int, y: Int, sampler: Sampler) -> Block {
        let partialImage = Array2d(x: Int(size.x), y: Int(size.y), value: Color())
        var block = Block(position: Vec2(Float(x), Float(y)), size: size, sample: sampler, image: partialImage, intersectionCount: 0, rayCount: 0)
        
        for lx in 0 ..< Int(block.size.x) {
            for ly in 0 ..< Int(block.size.y) {
                let x = lx + Int(block.position.x)
                let y = ly + Int(block.position.y)
                
                // Monte carlo
                var avg = Color()
                for _ in (0 ..< sampler.nbSamples) {
                    let pos = Vec2(Float(x), Float(y)) + sampler.next2()
                    var value = integrator.li(pixel: pos, scene: scene, sampler: sampler)
                    // sanitize nan values
                    if value.x != value.x { value.x = 0 }
                    if value.y != value.y { value.y = 0 }
                    if value.z != value.z { value.z = 0 }
                    avg += value
                }
                
                partialImage[lx, ly] = avg / Float(sampler.nbSamples)
            }
        }
        
        block.image = partialImage
        return block
    }
}

private extension [MonteCarloIntegrator.Block] {
    func assemble(into image: Array2d<Color>) -> Array2d<Color> {
        for block in self {
            for x in (0 ..< Int(block.size.x)) {
                for y in (0 ..< Int(block.size.y)) {
                    let (dx, dy): (Int, Int) = (x + Int(block.position.x), y + Int(block.position.y))
                    image[dx, dy] = block.image[x, y]
                }
            }
        }
        
        return image
    }
}

//
//  gdpt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-07.
//

import Foundation
import Progress

/// Gradient domain metropolis light transport integrator
final class GdptIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case shiftMapping
        case reconstruction
        case maxDepth
        case minDepth
    }
    
    private let maxDepth: Int
    private let minDepth: Int
    private let mapper: ShiftMapping
    private let reconstructor: Reconstructing
    private var successfulShifts: Int = 0
    private var failedShifts: Int = 0

    private let gradientOffsets: [Vec2] = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]
    init(mapper: ShiftMapping, reconstructor: Reconstructing, maxReconstructIterations: Int, minDepth: Int = 0, maxDepth: Int = 16) {
        self.mapper = mapper
        self.reconstructor = reconstructor
        self.minDepth = minDepth
        self.maxDepth = maxDepth
    }

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let result: GradientDomainResult = render(scene: scene, sampler: sampler)
        return result.img
    }
}

// MARK:  Gradient tracing

extension GdptIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: any Sampler) {
        mapper.initialize(sampler: sampler, scene: scene)
    }
    
    func li(ray: Ray, scene: Scene, sampler: any Sampler) -> Color {
        fatalError("Not implemented")
    }
    
    func li(pixel: Vec2, scene: Scene, sampler: Sampler) -> Color {
        let result = mapper.shift(pixel: pixel)
        return result.main
    }
}
                 
// MARK:  Rendering blocks

extension GdptIntegrator: GradientDomainIntegrator {
    internal struct Block {
        let position: Vec2
        let size: Vec2
        let image: Array2d<Color>
        let dxGradients: Array2d<Color>
        let dyGradients: Array2d<Color>
    }
    
    func render(scene: Scene, sampler: any Sampler) -> GradientDomainResult {
        print("Integrator preprocessing ...")
        preprocess(scene: scene, sampler: sampler)
        
        print("Rendering ...")
        let img = Array2d<Color>(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: .zero)
        let dxGradients = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        let dyGradients = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)

        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: Int(scene.camera.resolution.x) / 32 * Int(scene.camera.resolution.y) / 32, printer: Printer())
            let blocks = await renderBlocks(scene: scene, mapper: mapper) {
                progress.next()
            }
            
            return blocks.assemble(into: img, dx: dxGradients, dy: dyGradients)
        }
        
        gcd.wait()
        
        print("Reconstructing with dx and dy ...")
        let reconstruction = reconstructor.reconstruct(image: img, dx: dxGradients, dy: dyGradients)
        
        // Rework how these stats are built within the shift happening along the main path
//        print("Successful shifts => \(successfulShifts)")
//        print("Failed shifts     => \(failedShifts)")
        return GradientDomainResult(
            img: reconstruction,
            dx: dxGradients.transformed { $0.abs },
            dy: dyGradients.transformed { $0.abs }
        )
        
    }
    
    private func renderBlocks(blockSize: Int = 32, scene: Scene, mapper: ShiftMapping, increment: @escaping () -> Void) async -> [Block] {
        return await withTaskGroup(of: Block.self) { group in
            for x in stride(from: 0, to: Int(scene.camera.resolution.x), by: blockSize) {
                for y in stride(from: 0, to: Int(scene.camera.resolution.y), by: blockSize) {
                    let size = Vec2(
                        min(scene.camera.resolution.x - Float(x), Float(blockSize)),
                        min(scene.camera.resolution.y - Float(y), Float(blockSize))
                    )
                    
                    group.addTask {
                        increment()
                        return self.renderBlock(scene: scene, size: size, x: x, y: y, mapper: mapper)
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

    private func renderBlock(scene: Scene, size: Vec2, x: Int, y: Int, mapper: ShiftMapping) -> Block {
        let img = Array2d(x: Int(size.x), y: Int(size.y), value: Color())
        let dxGradients = Array2d<Color>(x: img.xSize + 1, y: img.ySize + 1, value: .zero)
        let dyGradients = Array2d<Color>(x: img.xSize + 1, y: img.ySize + 1, value: .zero)
        for lx in 0 ..< Int(size.x) {
            for ly in 0 ..< Int(size.y) {
                for _ in 0 ..< mapper.sampler.nbSamples {
                    let x = lx + x
                    let y = ly + y

                    let base = Vec2(Float(x), Float(y)) + mapper.sampler.next2()
                    let newResult = mapper.shift(pixel: base)
                    img[lx, ly] += newResult.main
                    
                    for (i, offset) in gradientOffsets.enumerated() {
                        let xShift = lx + Int(offset.x)
                        let yShift = ly + Int(offset.y)
                        
                        // TODO Cleaner check
                        // TODO img needs to be of the same size as dx and dy now, since we reuse primal from radiances of shifted paths
                        if (0 ..< Int(size.x)).contains(xShift) && (0 ..< Int(size.y)).contains(yShift) {
                            img[xShift, yShift] += newResult.radiances[i]
                        }
                        
                        let forward = offset.sum() > 0
                        let delta = if forward { newResult.gradients[i] } else { newResult.gradients[i] * -1 }
                        if offset.x == 0 {
                            dyGradients[lx+1, forward ? ly+1 : ly] += delta
                        } else {
                            dxGradients[forward ? lx+1 : lx, ly+1] += delta
                        }
                    }
                }
            }
        }
        
        let scaleFactor: Float = 1.0 / Float(mapper.sampler.nbSamples)
        img.scale(by: scaleFactor * 0.25)
        dxGradients.scale(by: scaleFactor)
        dyGradients.scale(by: scaleFactor)
        return Block(
            position: Vec2(Float(x), Float(y)),
            size: size,
            image: img,
            dxGradients: dxGradients,
            dyGradients: dyGradients
        )
    }
}

private extension [GdptIntegrator.Block] {
    func assemble(into image: Array2d<Color>, dx: Array2d<Color>, dy: Array2d<Color>) -> GradientDomainResult {
        for block in self {
            for lx in (0 ..< Int(block.size.x)) {
                for ly in (0 ..< Int(block.size.y)) {
                    let (x, y): (Int, Int) = (lx + Int(block.position.x), ly + Int(block.position.y))
                    image[x, y] = block.image[lx, ly]
                    if lx == 0 && x != 0 { dx[x - 1, y] += block.dxGradients[lx, ly] }
                    if ly == 0 && y != 0 { dy[x, y - 1] += block.dyGradients[lx, ly] }
                    dx[x, y] += block.dxGradients[lx+1, ly+1]
                    dy[x, y] += block.dyGradients[lx+1, ly+1]
                }
            }
        }
        
        return GradientDomainResult(img: image, dx: dx, dy: dy)
    }
}

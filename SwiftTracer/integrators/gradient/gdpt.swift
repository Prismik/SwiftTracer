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
    
    let identifier = "gdpt"
    let mapper: ShiftMapping
    
    private let maxDepth: Int
    private let minDepth: Int
    private let reconstructor: Reconstructing
    private var successfulShifts: Int = 0
    private var failedShifts: Int = 0
    private let sanitize: Bool = true

    init(mapper: ShiftMapping, reconstructor: Reconstructing, maxReconstructIterations: Int, minDepth: Int = 0, maxDepth: Int = 16) {
        self.mapper = mapper
        self.reconstructor = reconstructor
        self.minDepth = minDepth
        self.maxDepth = maxDepth
    }

    func render(scene: Scene, sampler: any Sampler) -> PixelBuffer {
        let result: GradientDomainResult = render(scene: scene, sampler: sampler)
        return result.img
    }
}

// MARK:  Gradient tracing

extension GdptIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: any Sampler) {
        mapper.initialize(scene: scene)
    }
    
    func li(ray: Ray, scene: Scene, sampler: any Sampler) -> Color {
        fatalError("Not implemented")
    }
    
    func li(pixel: Vec2, scene: Scene, sampler: Sampler) -> Color {
        let result = mapper.shift(pixel: pixel, sampler: sampler, params: ShiftMappingParams(offsets: nil))
        return result.main
    }
}
                 
// MARK:  Rendering blocks

extension GdptIntegrator: GradientDomainIntegrator {
    internal struct Block {
        let position: Vec2
        let size: Vec2
        let image: PixelBuffer
        let directLight: PixelBuffer
        let dxGradients: PixelBuffer
        let dyGradients: PixelBuffer
    }
    
    func render(scene: Scene, sampler: any Sampler) -> GradientDomainResult {
        print("Rendering ...")
        let img = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
        let directLight = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
        let dxGradients = PixelBuffer(width: img.width, height: img.height, value: .zero)
        let dyGradients = PixelBuffer(width: img.width, height: img.height, value: .zero)

        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: Int(scene.camera.resolution.x) / 32 * Int(scene.camera.resolution.y) / 32, printer: Printer())
            let blocks = await renderBlocks(scene: scene, mapper: mapper, sampler: sampler) {
                progress.next()
            }
            
            return blocks.assemble(into: img, directLight: directLight, dx: dxGradients, dy: dyGradients)
        }
        
        gcd.wait()

        return GradientDomainResult(
            primal: img,
            directLight: directLight,
            img: .empty,
            dx: dxGradients,
            dy: dyGradients
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
    
    private func renderBlocks(blockSize: Int = 32, scene: Scene, mapper: ShiftMapping, sampler: Sampler, increment: @escaping () -> Void) async -> [Block] {
        return await withTaskGroup(of: Block.self) { group in
            for x in stride(from: 0, to: Int(scene.camera.resolution.x), by: blockSize) {
                for y in stride(from: 0, to: Int(scene.camera.resolution.y), by: blockSize) {
                    let size = Vec2(
                        min(scene.camera.resolution.x - Float(x), Float(blockSize)),
                        min(scene.camera.resolution.y - Float(y), Float(blockSize))
                    )
                    
                    group.addTask {
                        increment()
                        return self.renderBlock(scene: scene, size: size, x: x, y: y, mapper: mapper, sampler: sampler)
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

    private func renderBlock(scene: Scene, size: Vec2, x: Int, y: Int, mapper: ShiftMapping, sampler: Sampler) -> Block {
        let sampler = sampler.new(nspp: sampler.nbSamples)
        let imgSize = Vec2(size.x + 2, size.y + 2)
        let img = PixelBuffer(width: Int(imgSize.x), height: Int(imgSize.y), value: .zero)
        let directLight = PixelBuffer(width: Int(imgSize.x), height: Int(imgSize.y), value: .zero)
        let dxGradients = PixelBuffer(width: Int(imgSize.x), height: Int(imgSize.y), value: .zero)
        let dyGradients = PixelBuffer(width: Int(imgSize.x), height: Int(imgSize.y), value: .zero)
        for lx in 0 ..< Int(size.x) {
            for ly in 0 ..< Int(size.y) {
                for _ in 0 ..< sampler.nbSamples {
                    let x = lx + x
                    let y = ly + y

                    let base = Vec2(Float(x), Float(y)) + sampler.next2()
                    let newResult = mapper.shift(pixel: base, sampler: sampler, params: ShiftMappingParams(offsets: nil))
                    if sanitize && newResult.main.luminance > 100 {
                        img[lx+1, ly+1] += newResult.main / newResult.main.luminance
                    } else {
                        img[lx+1, ly+1] += newResult.main
                    }
                
                    directLight[lx+1, ly+1] += newResult.directLight
                    for (i, offset) in mapper.gradientOffsets.enumerated() {
                        let xShift = lx + 1 + Int(offset.x)
                        let yShift = ly + 1 + Int(offset.y)
                        
                        if (0 ..< img.width).contains(xShift) && (0 ..< img.height).contains(yShift) {
                            if sanitize && newResult.radiances[i].luminance > 100 {
                                img[xShift, yShift] += newResult.radiances[i] / newResult.radiances[i].luminance
                            } else {
                                img[xShift, yShift] += newResult.radiances[i]
                            }
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
        
        let scaleFactor: Float = 1.0 / Float(sampler.nbSamples)
        img.scale(by: scaleFactor * 0.25)
        directLight.scale(by: scaleFactor)
        dxGradients.scale(by: scaleFactor)
        dyGradients.scale(by: scaleFactor)
        return Block(
            position: Vec2(Float(x), Float(y)),
            size: size,
            image: img,
            directLight: directLight,
            dxGradients: dxGradients,
            dyGradients: dyGradients
        )
    }
}

private extension [GdptIntegrator.Block] {
    func assemble(into image: PixelBuffer, directLight: PixelBuffer, dx: PixelBuffer, dy: PixelBuffer) -> GradientDomainResult {
        for block in self {
            for lx in (-1 ..< Int(block.size.x) + 1) {
                for ly in (-1 ..< Int(block.size.y) + 1) {
                    let (x, y): (Int, Int) = (lx + Int(block.position.x), ly + Int(block.position.y))
                    guard x >= 0 && x < image.width else { continue }
                    guard y >= 0 && y < image.height else { continue }

                    // Radiances from shift, computed into previous positions
                    image[x, y] += block.image[lx+1, ly+1]
                    directLight[x, y] += block.directLight[lx+1, ly+1]

                    // Backward facing gradients
                    dx[x, y] += block.dxGradients[lx+1, ly+1]
                    dy[x, y] += block.dyGradients[lx+1, ly+1]
                }
            }
        }
        
        return GradientDomainResult(primal: image, directLight: directLight, img: .empty, dx: dx, dy: dy)
    }
}

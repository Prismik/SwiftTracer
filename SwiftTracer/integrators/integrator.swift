//
//  integrator.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-18.
//

import Foundation

enum IntegratorType {
    case Path
    case Normal
    case UV
    case Direct
    case PathMis
}

/// Integrating one pixel at a time
protocol SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler)
    /// Estimate the incoming light for a given ray
    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color
}

protocol Integrator {
    func render(scene: Scene, sampler: Sampler) -> Array2d<Color>
}

extension Integrator {
    static func from(json: Data) -> Integrator? {
        return nil
    }
}

private struct Block {
    let position: Vec2
    let size: Vec2
    let sample: Sampler
    var image: Array2d<Color>
    var intersectionCount: Int
    var rayCount: Int
}

func render<T: SamplerIntegrator>(integrator: T, scene: Scene, sampler: Sampler) -> Array2d<Color> {
    integrator.preprocess(scene: scene, sampler: sampler)
    
    let image = Array2d(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: Color())
    let gcd = DispatchGroup()
    gcd.enter()
    Task {
        defer { gcd.leave() }
        let blockSize = 32
        let blocks = await withTaskGroup(of: Block.self) { group in
            for x in stride(from: 0, to: Int(scene.camera.resolution.x), by: blockSize) {
                for y in stride(from: 0, to: Int(scene.camera.resolution.y), by: blockSize) {
                    let size = Vec2(
                        min(scene.camera.resolution.x - Float(x), Float(blockSize)),
                        min(scene.camera.resolution.y - Float(y), Float(blockSize))
                    )
                    
                    group.addTask {
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
                                    let ray = scene.camera.createRay(from: pos)
                                    let value = integrator.li(ray: ray, scene: scene, sampler: sampler)
                                    avg += value
                                }
                                
                                partialImage.set(value: avg / Float(sampler.nbSamples), lx, ly)
                            }
                        }
                        
                        block.image = partialImage
                        return block
                    }
                    
                    
                }
            }
            
            var blocks: [Block] = []
            for await block in group {
                blocks.append(block)
            }
            
            return blocks
        }
        
        for block in blocks {
            for x in (0 ..< Int(block.size.x)) {
                for y in (0 ..< Int(block.size.y)) {
                    image.set(value: block.image.get(x, y), x + Int(block.position.x), y + Int(block.position.y))
                }
            }
        }
        
        return image
    }

    gcd.wait()
    return image
}

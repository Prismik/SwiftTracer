//
//  integrator.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-18.
//

import Foundation
import Progress

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

private struct Printer: ProgressBarPrinter {
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

func render<T: SamplerIntegrator>(integrator: T, scene: Scene, sampler: Sampler) -> Array2d<Color> {
    print("Integrator preprocessing ...")
    integrator.preprocess(scene: scene, sampler: sampler)

    print("Rendering ...")
    let image = Array2d(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: Color())
    let gcd = DispatchGroup()
    gcd.enter()
    Task {
        defer { gcd.leave() }
        var progress = ProgressBar(count: Int(scene.camera.resolution.x) / 32 * Int(scene.camera.resolution.y) / 32, printer: Printer())
        let blocks = await renderBlocks(blockSize: 32, scene: scene, integrator: integrator, sampler: sampler) {
            progress.next()
        }
        return assemble(renderBlocks: blocks, image: image)
    }

    gcd.wait()
    return image
}

private func assemble(renderBlocks: [Block], image: Array2d<Color>) -> Array2d<Color> {
    for block in renderBlocks {
        for x in (0 ..< Int(block.size.x)) {
            for y in (0 ..< Int(block.size.y)) {
                image.set(value: block.image.get(x, y), x + Int(block.position.x), y + Int(block.position.y))
            }
        }
    }
    
    return image
}

private func renderBlocks(blockSize: Int = 32, scene: Scene, integrator: SamplerIntegrator, sampler: Sampler, increment: @escaping () -> Void) async -> [Block] {
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

private func renderMonteCarlo(scene: Scene, integrator: SamplerIntegrator, size: Vec2, x: Int, y: Int, sampler: Sampler) -> Block {
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

//
//  gdmlt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-07.
//

import Progress

/// Gradient domain metropolis light transport integrator
final class GdmltIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case mis
        case maxDepth
        case minDepth
    }
    
    private let maxReconstructIterations: Int
    private let integrator = PathIntegrator(minDepth: 0, maxDepth: 16)
    
    init(maxReconstructIterations: Int) {
        self.maxReconstructIterations = maxReconstructIterations
    }

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let result: GradientDomainResult = render(scene: scene, sampler: sampler)
        return result.img
    }
    
    private func reconstruct(image img: Array2d<Color>, dxGradients: Array2d<Color>, dyGradients: Array2d<Color>) -> Array2d<Color> {
        let j = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        var final = Array2d<Color>(copy: img)
        let max: (x: Int, y: Int) = (x: Int(img.xSize - 1), y: Int(img.ySize - 1))
        for _ in 0 ..< maxReconstructIterations {
            for x in 0 ..< img.xSize {
                for y in 0 ..< img.ySize {
                    var value = final[x, y]
                    
                    if x != 0 { value += final[x - 1, y] + dxGradients[x - 1, y] }
                    if y != 0 { value += final[x, y - 1] + dyGradients[x, y - 1] }
                    if x != max.x { value += final[x + 1, y] }
                    value += dxGradients[x, y]
                    if y != max.y { value += final[x, y + 1] }
                    value += dyGradients[x, y]
                    j[x, y] = value / 5
                }
            }
            
            final = j
        }
        return final
    }
}

extension GdmltIntegrator: GradientDomainIntegrator {
    func render(scene: Scene, sampler: any Sampler) -> GradientDomainResult {
        var sampler = sampler
        let img = Array2d<Color>(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: .zero)
        let dxGradients = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        let dyGradients = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        var progress = ProgressBar(count: sampler.nbSamples, printer: Printer())
        for _ in 0 ..< sampler.nbSamples {
            for x in 0 ..< img.xSize {
                for y in 0 ..< img.ySize {
                    let originalSeed = sampler.rng.state
                    let base = Vec2(Float(x), Float(y))
                    let pixel = integrator.render(pixel: base, scene: scene, sampler: sampler)
                    img[x, y] += pixel
                    // TODO Does it overlap to end of img or we don't use it
                    // TODO Check that the ray to replay is appropriate
                    // TODO Check that we can consider x,y < 0 and xy > max as Color.zero
                    let left = render(pixel: base - Vec2(1, 0), using: originalSeed, scene: scene, sampler: &sampler)
                    let right = render(pixel: base + Vec2(1, 0), using: originalSeed, scene: scene, sampler: &sampler)
                    let top = render(pixel: base - Vec2(0, 1), using: originalSeed, scene: scene, sampler: &sampler)
                    let bottom = render(pixel: base + Vec2(0, 1), using: originalSeed, scene: scene, sampler: &sampler)
                    
                    // TODO Double check the convention with (y + 1) and (y - 1)
                    dxGradients[x - 1, y] += 0.5 * (pixel - left)
                    dyGradients[x, y - 1] += 0.5 * (pixel - top)
                    dxGradients[x, y] += 0.5 * (right - pixel)
                    dyGradients[x, y] += 0.5 * (bottom - pixel)
                }
            }
            
            progress.next()
        }
        
        print("Reconstructing with dx and dy ...")
        let scaleFactor: Float = 1.0 / Float(sampler.nbSamples)
        img.scale(by: scaleFactor)
        dxGradients.scale(by: scaleFactor)
        dyGradients.scale(by: scaleFactor)
        return GradientDomainResult(
            img: reconstruct(image: img, dxGradients: dxGradients, dyGradients: dyGradients),
            dx: dxGradients,
            dy: dyGradients
        )
    }
    
    private func render(pixel: Vec2, using seed: UInt64, scene: Scene, sampler: inout Sampler) -> Color {
        guard pixel.x > 0, pixel.y > 0, pixel.x < scene.camera.resolution.x - 1, pixel.y < scene.camera.resolution.y - 1 else { return .zero }
        sampler.rng.state = seed
        return integrator.render(pixel: pixel, scene: scene, sampler: sampler)
    }
}

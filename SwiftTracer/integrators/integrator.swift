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

// TODO Parralel computation of image by blocks
func render<T: SamplerIntegrator>(integrator: T, scene: Scene, sampler: Sampler) -> Array2d<Color> {
    integrator.preprocess(scene: scene, sampler: sampler)
    let image = Array2d(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: Color())
    for x in (0..<Int(scene.camera.resolution.x)) {
        for y in (0..<Int(scene.camera.resolution.y)) {
            // Monte carlo
            var avg = Color()
            for _ in (0..<sampler.nbSamples) {
                let pos = Vec2(Float(x), Float(y)) + sampler.next2()
                let ray = scene.camera.createRay(from: pos)
                let value = integrator.li(ray: ray, scene: scene, sampler: sampler)
                avg += value
            }
            
            image.set(value: avg / Float(sampler.nbSamples), x, y)
        }
    }

    return image
}

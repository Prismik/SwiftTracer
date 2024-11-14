//
//  uv.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-04.
//

import Foundation

final class UvIntegrator: Integrator {
    let identifier = "uv"

    func render(scene: Scene, sampler: Sampler) -> Array2d<Color> {
        return MonteCarloIntegrator.render(integrator: self, scene: scene, sampler: sampler)
    }
}

extension UvIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler) {
        
    }
    
    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard let intersection = scene.hit(r: ray) else { return .zero }
        let uv = intersection.uv
        return Vec3(uv.x.modulo(1.0), uv.y.modulo(1.0), 0)
    }
    
    func li(pixel: Vec2, scene: Scene, sampler: Sampler) -> Color {
        let ray = scene.camera.createRay(from: pixel)
        return li(ray: ray, scene: scene, sampler: sampler)
    }
}

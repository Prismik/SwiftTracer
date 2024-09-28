//
//  uv.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-04.
//

import Foundation

final class UvIntegrator: Integrator {
    func render(scene: Scene, sampler: Sampler) -> Array2d<Color> {
        return MonteCarloIntegrator.render(integrator: self, scene: scene, sampler: sampler)
    }
}

extension UvIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler) {
        
    }
    
    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard let intersection = scene.hit(r: ray) else { return Color() }
        let uv = intersection.uv
        return Vec3(uv.x.modulo(1.0), uv.y.modulo(1.0), 0)
    }
    
    func render(pixel: (x: Int, y: Int), scene: Scene, sampler: Sampler) -> Color {
        return Color()
    }
}

//
//  normal.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-26.
//

import Foundation

final class NormalIntegrator: Integrator {
    func render(scene: Scene, sampler: Sampler) -> Array2d<Color> {
        return MonteCarloIntegrator.render(integrator: self, scene: scene, sampler: sampler)
    }
}

extension NormalIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler) {
        
    }
    
    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard let intersection = scene.hit(r: ray) else { return Color() }
        return (intersection.n + Vec3(repeating: 1)) * 0.5
    }
    
    func render(pixel: (x: Int, y: Int), scene: Scene, sampler: Sampler) -> Color {
        return Color()
    }
}

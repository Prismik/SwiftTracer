//
//  uv.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-04.
//

import Foundation

final class UvIntegrator: Integrator {
    func render(scene: Scene, sampler: Sampler) -> Array2d<Color> {
        return SwiftTracer.render(integrator: self, scene: scene, sampler: sampler)
    }
}

extension UvIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler) {
        
    }
    
    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard let intersection = scene.hit(r: ray) else { return Color() }
        let uv = intersection.uv
        return Vec3(modulo(uv.x, 1.0), modulo(uv.y, 1.0), 0)
    }
    
    private func modulo(_ a: Float, _ b: Float) -> Float {
        let r = a.truncatingRemainder(dividingBy: b)
        return r < 0
            ? r + b
            : r
    }
}

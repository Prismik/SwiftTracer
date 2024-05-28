//
//  path.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-18.
//

import Foundation

final class PathIntegrator: Integrator {
    let maxDepth = 16
    func render(scene: Scene, sampler: Sampler) -> Array2d<Color> {
        return SwiftTracer.render(integrator: self, scene: scene, sampler: sampler)
    }
}

extension PathIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler) {
        
    }

    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        var depth = 0
        var throughput = Color(1, 1, 1)
        var currentRay = ray
        while depth != maxDepth {
            depth += 1
            guard currentRay.d.length.isFinite else {
                return Color()
            }
            if let intersection = scene.hit(r: currentRay) {
                let frame = Frame(n: intersection.n)
                let wo = frame.toLocal(v: -currentRay.d)
                if let direction = intersection.material.sample(
                    wo: wo,
                    uv: intersection.uv,
                    p: intersection.p,
                    sample: sampler.next2()
                ) {
                    let wi = frame.toWorld(v: direction.wi)
                    currentRay = Ray(origin: intersection.p, direction: wi)
                    throughput *= direction.weight
                } else {
                    return throughput * intersection.material.emission(wo: wo, uv: intersection.uv, p: intersection.p)
                }
            }
        }
        
        return throughput
    }
}

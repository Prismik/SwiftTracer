//
//  direct.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-07.
//

import Foundation

final class DirectIntegrator: Integrator {
    func render(scene: Scene, sampler: Sampler) -> Array2d<Color> {
        return SwiftTracer.render(integrator: self, scene: scene, sampler: sampler)
    }
}

extension DirectIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler) {
        
    }
    
    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard let intersection = scene.hit(r: ray) else { return scene.background }
        let sample = sampler.next2()
        let p = intersection.p
        let uv = intersection.uv
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        if intersection.material.hasEmission {
            return intersection.material.emission(wo: wo, uv: uv, p: p)
        } else {
            var contribution = Color()
            let s = scene.root.sampleDirect(p: p, sample: sample) // TODO Check why we even do this
            
            // Directly visible from sampled point
            if p.visible(from: s.y, within: scene) {
                let wi = (s.y - p).normalized()
                let localWi = frame.toLocal(v: wi)
                let pdf = intersection.material.pdf(wo: wo, wi: localWi, uv: uv, p: p)
                let eval = intersection.material.evaluate(wo: wo, wi: wi, uv: uv, p: p)
                let weight = s.pdf / (pdf + s.pdf)
                let localFrame = Frame(n: s.n)
                let newWo = localFrame.toLocal(v: -wi).normalized()
                contribution += (weight * eval / s.pdf)
                    * s.shape.material.emission(wo: newWo, uv: s.uv, p: s.y)
            }
            
            // First bounce
            if let direction = intersection.material.sample(wo: wo, uv: uv, p: p, sample: sample) {
                let wi = frame.toWorld(v: direction.wi)
                let newRay = Ray(origin: p, direction: wi)
                
                if let newIntersection = scene.hit(r: newRay) {
                    // First bounce on a light source
                    if newIntersection.material.hasEmission {
                        let localFrame = Frame(n: newIntersection.n)
                        let newWo = frame.toLocal(v: -newRay.d).normalized()
                        let eval = intersection.material.evaluate(wo: wo, wi: direction.wi, uv: intersection.uv, p: intersection.p)
                        let pdf = intersection.material.pdf(wo: wo, wi: direction.wi, uv: intersection.uv, p: intersection.p)
                        var weight: Float = 1
                        if !intersection.material.hasDelta(uv: uv, p: p) {
                            let pdfDirect = scene.root.pdfDirect(shape: newIntersection.shape, p: p, y: newIntersection.p, n: newIntersection.n)
                            weight = pdf / (pdf + pdfDirect)
                        }
                        contribution += (weight * eval / pdf)
                            * newIntersection.material.emission(wo: newWo, uv: newIntersection.uv, p: newIntersection.p)
                    }
                } else {
                    contribution += direction.weight * scene.background
                }
            }
            
            return contribution
        }
    }
}

//
//  direct.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-07.
//

import Foundation

final class DirectIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case strategy
    }

    enum Strategy: String, Decodable {
        case mis
        case bsdf
        case eval
        case emitter
    }

    let strategy: Strategy
    init(strategy: Strategy) {
        self.strategy = strategy
    }

    func render(scene: Scene, sampler: Sampler) -> Array2d<Color> {
        return SwiftTracer.render(integrator: self, scene: scene, sampler: sampler)
    }
}

extension DirectIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler) {
        
    }

    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        switch strategy {
        case .bsdf:
            return bsdf(ray: ray, scene: scene, sampler: sampler)
        case .mis:
            return mis(ray: ray, scene: scene, sampler: sampler)
        case .eval:
            return eval(ray: ray, scene: scene, sampler: sampler)
        case .emitter:
            return emitter(ray: ray, scene: scene, sampler: sampler)
        }
    }
    
    private func mis(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard let intersection = scene.hit(r: ray) else { return scene.background }

        let p = intersection.p
        let uv = intersection.uv
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        // First intersection is a light source, end here
        if intersection.hasEmission {
            return intersection.shape.light.L(p: p, n: intersection.n, uv: uv, wo: wo)
        }

        var contribution = Color()
        let sample = sampler.next2()
        
        // NEW LIGHT HANDLING
        let ctx = LightSample.Context(p: p, n: intersection.n, ns: intersection.n)
        if let sample = scene.sample(context: ctx, s: sample) {
            let localWi = frame.toLocal(v: sample.wi).normalized()
            let pdf = intersection.shape.material.pdf(wo: wo, wi: localWi, uv: uv, p: p)
            let eval = intersection.shape.material.evaluate(wo: wo, wi: localWi, uv: uv, p: p)
            let weight = sample.pdf / (pdf + sample.pdf)
            
            contribution += (weight * eval / sample.pdf) * sample.L
        }

        // First bounce
        guard let direction = intersection.shape.material.sample(wo: wo, uv: uv, p: p, sample: sample) else { return contribution }
        let wi = frame.toWorld(v: direction.wi).normalized()
        let newRay = Ray(origin: p, direction: wi)
        
        if let newIntersection = scene.hit(r: newRay) {
            // First bounce on a light source
            if newIntersection.hasEmission, let light = newIntersection.shape.light {
                let localFrame = Frame(n: newIntersection.n)
                let newWo = localFrame.toLocal(v: -newRay.d).normalized()
                let eval = intersection.shape.material.evaluate(wo: wo, wi: direction.wi, uv: uv, p: p)
                let pdf = intersection.shape.material.pdf(wo: wo, wi: direction.wi, uv: uv, p: p)
                var weight: Float = 1
                if !intersection.shape.material.hasDelta(uv: uv, p: p) {
                    let pdfDirect = light.pdfLi(context: ctx, y: newIntersection.p)
                    weight = pdf / (pdf + pdfDirect)
                }
                contribution += (weight * eval / pdf)
                    * light.L(p: newIntersection.p, n: newIntersection.n, uv: newIntersection.uv, wo: newWo)
            }
        } else {
            contribution += direction.weight * scene.background
        }
        
        return contribution
    }
    
    private func emitter(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard let intersection = scene.hit(r: ray) else { return scene.background }

        let p = intersection.p
        let uv = intersection.uv
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        // First intersection is a light source, end here
        guard !intersection.hasEmission else {
            return intersection.shape.light.L(p: p, n: intersection.n, uv: uv, wo: wo)
        }
        
        guard !intersection.shape.material.hasDelta(uv: uv, p: p) else {
            return bsdf(ray: ray, scene: scene, sampler: sampler)
        }
        
        let sample = sampler.next2()
        let ctx = LightSample.Context(p: p, n: intersection.n, ns: intersection.n)
        guard let light = scene.sample(context: ctx, s: sample) else { return Color() }
        let eval = intersection.shape.material.evaluate(wo: wo, wi: frame.toLocal(v: light.wi), uv: uv, p: p)
        
        return (eval / light.pdf) * light.L
    }
    
    private func eval(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard let intersection = scene.hit(r: ray) else { return scene.background }

        let p = intersection.p
        let uv = intersection.uv
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        // First intersection is a light source, end here
        guard !intersection.hasEmission else {
            return intersection.shape.light.L(p: p, n: intersection.n, uv: uv, wo: wo)
        }
        
        guard !intersection.shape.material.hasDelta(uv: uv, p: p) else {
            return bsdf(ray: ray, scene: scene, sampler: sampler)
        }

        let sample = sampler.next2()
        guard let direction = intersection.shape.material.sample(wo: wo, uv: uv, p: p, sample: sample) else { return Color() }
        let wi = frame.toWorld(v: direction.wi).normalized()
        let newRay = Ray(origin: intersection.p, direction: wi)
        
        let eval = intersection.shape.material.evaluate(wo: wo, wi: direction.wi, uv: uv, p: p)
        let pdf = intersection.shape.material.pdf(wo: wo, wi: direction.wi, uv: uv, p: p)
    
        guard let newIts = scene.hit(r: newRay) else { return (eval / pdf) * scene.background }
        let localFrame = Frame(n: newIts.n)
        let localWo = localFrame.toLocal(v: -newRay.d).normalized()
        return newIts.hasEmission
            ? (eval / pdf) * newIts.shape.light.L(p: newIts.p, n: newIts.n, uv: newIts.uv, wo: localWo)
            : Color()
    }

    private func bsdf(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard let intersection = scene.hit(r: ray) else { return scene.background }

        let p = intersection.p
        let uv = intersection.uv
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        // First intersection is a light source, end here
        guard !intersection.hasEmission else {
            return intersection.shape.light.L(p: p, n: intersection.n, uv: uv, wo: wo)
        }
        
        let sample = sampler.next2()
        guard let direction = intersection.shape.material.sample(wo: wo, uv: uv, p: p, sample: sample) else { return Color() }
        let wi = frame.toWorld(v: direction.wi).normalized()
        let newRay = Ray(origin: intersection.p, direction: wi)
        guard let newIts = scene.hit(r: newRay) else { return direction.weight * scene.background }
        let localFrame = Frame(n: newIts.n)
        let localWo = localFrame.toLocal(v: -newRay.d).normalized()
        return newIts.hasEmission
            ? direction.weight * newIts.shape.light.L(p: newIts.p, n: newIts.n, uv: newIts.uv, wo: localWo)
            : Color()
    }
}

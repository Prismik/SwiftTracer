//
//  path.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-18.
//

import Foundation

final class PathIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case mis
        case depth
    }

    let maxDepth: Int
    let mis: Bool
    
    init(maxDepth: Int, mis: Bool = true) {
        self.maxDepth = maxDepth
        self.mis = mis
    }

    func render(scene: Scene, sampler: Sampler) -> Array2d<Color> {
        return SwiftTracer.render(integrator: self, scene: scene, sampler: sampler)
    }
    
    /// Evaluates direct lighting on a given intersection
    private func light(wo: Vec3, scene: Scene, frame: Frame, intersection: Intersection, s: Vec2) -> Color {
        let p = intersection.p
        let uv = intersection.uv
        
        let ctx = LightSample.Context(p: p, n: intersection.n, ns: intersection.n)
        guard let sample = scene.sample(context: ctx, s: s) else { return Color() }
        let localWi = frame.toLocal(v: sample.wi).normalized()
        let pdf = intersection.shape.material.pdf(wo: wo, wi: localWi, uv: uv, p: p)
        let eval = intersection.shape.material.evaluate(wo: wo, wi: localWi, uv: uv, p: p)
        let weight = sample.pdf / (pdf + sample.pdf)
        
        return (weight * eval / sample.pdf) * sample.L
    }
    
    /// Recursively traces rays using MIS
    private func trace(intersection: Intersection?, ray: Ray, scene: Scene, sampler: Sampler, depth: Int) -> Color {
        guard ray.d.length.isFinite else { return Color() }
        guard let intersection = intersection else { return scene.background }
        var contribution = Color()
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        let p = intersection.p
        let uv = intersection.uv
        let s = sampler.next2()
        
        guard !intersection.hasEmission else {
            return intersection.shape.light.L(p: p, n: intersection.n, uv: uv, wo: wo)
        }

        // MIS Emitter
        contribution += light(wo: wo, scene: scene, frame: frame, intersection: intersection, s: s)

        // MIS Material
        var weightMis = Color()
        var its: Intersection? = nil
        guard let direction = intersection.shape.material.sample(wo: wo, uv: uv, p: p, sample: s) else {
            return contribution
        }
        
        weightMis += direction.weight
        let wi = frame.toWorld(v: direction.wi).normalized()
        let newRay = Ray(origin: intersection.p, direction: wi)
        if let newIntersection = scene.hit(r: newRay) {
            its = newIntersection
            if newIntersection.hasEmission, let light = newIntersection.shape.light {
                let localFrame = Frame(n: newIntersection.n)
                let newWo = localFrame.toLocal(v: -newRay.d).normalized()
                let pdf = intersection.shape.material.pdf(wo: wo, wi: direction.wi, uv: uv, p: p)
                var weight: Float = 1
                if !intersection.shape.material.hasDelta(uv: uv, p: p) {
                    let ctx = LightSample.Context(p: p, n: intersection.n, ns: intersection.n)
                    let pdfDirect = light.pdfLi(context: ctx, y: newIntersection.p)
                    weight = pdf / (pdf + pdfDirect)
                }

                contribution += (weight * weightMis)
                    * light.L(p: newIntersection.p, n: newIntersection.n, uv: newIntersection.uv, wo: newWo)
            }
        }

        return depth == maxDepth || its?.hasEmission == true
            ? contribution + weightMis
            : contribution + trace(intersection: its, ray: newRay, scene: scene, sampler: sampler, depth: depth + 1) * weightMis
    }
}

extension PathIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler) {
        
    }

    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard mis else { return pathNoMis(ray: ray, scene: scene, sampler: sampler) }
        
        guard let intersection = scene.hit(r: ray) else { return scene.background }
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        
        return intersection.hasEmission
            ? intersection.shape.light.L(p: intersection.p, n: intersection.n, uv: intersection.uv, wo: wo)
            : trace(intersection: intersection, ray: ray, scene: scene, sampler: sampler, depth: 0)
    }
    
    private func pathNoMis(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        var depth = 0
        var throughput = Color(repeating: 1)
        var currentRay = ray
        while depth != maxDepth {
            depth += 1
            guard currentRay.d.length.isFinite else { return Color() }
            if let intersection = scene.hit(r: currentRay) {
                let frame = Frame(n: intersection.n)
                let wo = frame.toLocal(v: -currentRay.d).normalized()
                if intersection.hasEmission, let light = intersection.shape.light {
                    return throughput * light.L(p: intersection.p, n: intersection.n, uv: intersection.uv, wo: wo)
                } else if let direction = intersection.shape.material.sample(
                    wo: wo,
                    uv: intersection.uv,
                    p: intersection.p,
                    sample: sampler.next2()
                ) {
                    let wi = frame.toWorld(v: direction.wi).normalized()
                    currentRay = Ray(origin: intersection.p, direction: wi)
                    throughput *= direction.weight
                } else {
                    return Color()
                }
            } else {
                return throughput * scene.background
            }
        }

        return throughput
    }
}

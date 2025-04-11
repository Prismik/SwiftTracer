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
        case maxDepth
        case minDepth
    }

    let identifier = "path"
    let minDepth: Int
    let maxDepth: Int
    let mis: Bool
    
    init(minDepth: Int, maxDepth: Int, mis: Bool = true) {
        self.minDepth = minDepth
        self.maxDepth = maxDepth
        self.mis = mis
    }

    func render(scene: Scene, sampler: Sampler) -> PixelBuffer {
        print("Using \(maxDepth) path length")
        return MonteCarloIntegrator.render(integrator: self, scene: scene, sampler: sampler)
    }
    
    /// Evaluates direct lighting on a given intersection
    private func light(wo: Vec3, scene: Scene, frame: Frame, intersection: Intersection, s: Vec2) -> Color {
        guard !intersection.shape.material.hasDelta(uv: intersection.uv, p: intersection.p) else { return .zero }

        let ctx = LightSample.Context(p: intersection.p, n: intersection.n, ns: intersection.n)
        guard let lightSample = scene.sample(context: ctx, s: s) else { return .zero }

        let localWi = frame.toLocal(v: lightSample.wi).normalized()
        let pdf = intersection.shape.material.pdf(wo: wo, wi: localWi, uv: intersection.uv, p: intersection.p)
        let eval = intersection.shape.material.evaluate(wo: wo, wi: localWi, uv: intersection.uv, p: intersection.p)
        let weight = lightSample.pdf / (pdf + lightSample.pdf)
        
        return (weight * eval / lightSample.pdf) * lightSample.L
    }

    /// Recursively traces rays using MIS
    private func trace(intersection: Intersection?, ray: Ray, scene: Scene, sampler: Sampler, depth: Int) -> Color {
        guard ray.d.length.isFinite else { return .zero }
        guard let intersection = intersection else { return scene.environment(ray: ray) }
        var contribution = Color()
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        
        guard !intersection.hasEmission else {
            return intersection.shape.light.L(p: intersection.p, n: intersection.n, uv: intersection.uv, wo: wo)
        }
        
        // MIS Emitter
        contribution += light(wo: wo, scene: scene, frame: frame, intersection: intersection, s: sampler.next2())

        // MIS Material
        guard let direction = intersection.shape.material.sample(wo: wo, uv: intersection.uv, p: intersection.p, sample: sampler.next2()) else {
            return contribution
        }
        
        let bsdfWeight = direction.weight
        let wi = frame.toWorld(v: direction.wi).normalized()
        let newRay = Ray(origin: intersection.p, direction: wi)
        var its: Intersection? = nil
        if let newIntersection = scene.hit(r: newRay) {
            its = newIntersection
            if newIntersection.hasEmission, let light = newIntersection.shape.light {
                let localFrame = Frame(n: newIntersection.n)
                let newWo = localFrame.toLocal(v: -newRay.d).normalized()
                let pdf = intersection.shape.material.pdf(wo: wo, wi: direction.wi, uv: intersection.uv, p: intersection.p)
                var weight: Float = 1
                if !intersection.shape.material.hasDelta(uv: intersection.uv, p: intersection.p) {
                    let ctx = LightSample.Context(p: intersection.p, n: intersection.n, ns: intersection.n)
                    let pdfDirect = light.pdfLi(context: ctx, y: newIntersection.p)
                    weight = pdf / (pdf + pdfDirect)
                }

                contribution += (weight * bsdfWeight)
                    * light.L(p: newIntersection.p, n: newIntersection.n, uv: newIntersection.uv, wo: newWo)
            }
        }

        return depth == maxDepth || (its?.hasEmission == true && depth >= minDepth)
            ? contribution
            : contribution + trace(intersection: its, ray: newRay, scene: scene, sampler: sampler, depth: depth + 1) * bsdfWeight
    }
}

extension PathIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler) {
        
    }

    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        return mis
            ? pathMis(ray: ray, scene: scene, sampler: sampler)
            : pathNoMis(ray: ray, scene: scene, sampler: sampler)
    }
    
    func li(pixel: Vec2, scene: Scene, sampler: Sampler) -> Color {
        let ray = scene.camera.createRay(from: pixel)
        return mis
            ? pathMis(ray: ray, scene: scene, sampler: sampler)
            : pathNoMis(ray: ray, scene: scene, sampler: sampler)
    }
    
    private func pathMis(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        guard let intersection = scene.hit(r: ray) else { return scene.environment(ray: ray) }
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
            guard currentRay.d.length.isFinite else { return .zero }
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
                    return .zero
                }
            } else {
                return throughput * scene.environment(ray: currentRay)
            }
        }

        return throughput
    }
}

//
//  path.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-18.
//

import Foundation

final class PathIntegrator: Integrator {
    let maxDepth = 16
    let mis: Bool = true
    func render(scene: Scene, sampler: Sampler) -> Array2d<Color> {
        return SwiftTracer.render(integrator: self, scene: scene, sampler: sampler)
    }
    
    /// Evaluates direct lighting on a given intersection
    private func light(wo: Vec3, scene: Scene, frame: Frame, intersection: Intersection, s: Vec2) -> Color {
        let p = intersection.p
        let uv = intersection.uv
        let source = scene.root.sampleDirect(p: p, sample: s)
        guard source.y.visible(from: p, within: scene) else { return Color() }
        
        let wi = (source.y - p).normalized()
        let localWi = frame.toLocal(v: wi).normalized()
        let pdf = intersection.material.pdf(wo: wo, wi: localWi, uv: uv, p: p)
        let eval = intersection.material.evaluate(wo: wo, wi: localWi, uv: uv, p: p)
        let weight = source.pdf / (pdf + source.pdf)
        let localFrame = Frame(n: source.n)
        let newWo = localFrame.toLocal(v: -wi).normalized()

        return (weight * eval / source.pdf) * source.shape.material.emission(wo: newWo, uv: source.uv, p: source.y)
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
        
        // MIS Emitter
        contribution += light(wo: wo, scene: scene, frame: frame, intersection: intersection, s: s)

        // MIS Material
        var weightMis = Color()
        var its: Intersection? = nil
        guard let direction = intersection.material.sample(wo: wo, uv: uv, p: p, sample: s) else {
            return contribution
        }
        
        weightMis += direction.weight
        let wi = frame.toWorld(v: direction.wi).normalized()
        let newRay = Ray(origin: intersection.p, direction: wi)
        if let newIntersection = scene.hit(r: newRay) {
            its = newIntersection
            if newIntersection.material.hasEmission {
                let localFrame = Frame(n: newIntersection.n)
                let newWo = localFrame.toLocal(v: -newRay.d).normalized()
                let pdf = intersection.material.pdf(wo: wo, wi: direction.wi, uv: uv, p: p)
                var weight: Float = 1
                if !intersection.material.hasDelta(uv: uv, p: p) {
                    let pdfDirect = scene.root.pdfDirect(
                        shape: newIntersection.shape,
                        p: p,
                        y: newIntersection.p,
                        n: newIntersection.n
                    )
                    
                    weight = pdf / (pdf + pdfDirect)
                }

                contribution += (weight * weightMis)
                    * newIntersection.material.emission(
                        wo: newWo,
                        uv: newIntersection.uv,
                        p: newIntersection.p
                    )
            }
        }

        return depth == maxDepth
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
        return intersection.material.hasEmission
            ? intersection.material.emission(wo: wo, uv: intersection.uv, p: intersection.p)
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
                if let direction = intersection.material.sample(
                    wo: wo,
                    uv: intersection.uv,
                    p: intersection.p,
                    sample: sampler.next2()
                ) {
                    let wi = frame.toWorld(v: direction.wi).normalized()
                    currentRay = Ray(origin: intersection.p, direction: wi)
                    throughput *= direction.weight
                } else {
                    return throughput * intersection.material.emission(wo: wo, uv: intersection.uv, p: intersection.p)
                }
            } else {
                return throughput * scene.background
            }
        }

        return throughput
    }
}

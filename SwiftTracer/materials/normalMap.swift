//
//  normalMap.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-07.
//

import Foundation

/**
 Material that encapsulates normal information as a texture, which will affect the shading normal of an associated material.
 It allows to visually add surface detail without changing the geometry of an object.
 */
final class NormalMap: Material {
    /// The material that will see it's shading normal perturbed by the normals texture.
    let material: Material
    /// The normal values, where each channel of a pixel in the RGB image is used to encode a normal direction (R: x, G: y, B: z).
    let normals: Texture

    init(material: Material, normals: Texture) {
        self.material = material
        self.normals = normals
    }

    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection? {
        guard wo.z >= 0 else { return nil }
        
        let frame = Frame(n: normal(uv: uv, p: p))
        let wo = frame.toLocal(v: wo).normalized()
        
        guard let s = material.sample(wo: wo, uv: uv, p: p, sample: sample) else { return nil }
        let wi = frame.toWorld(v: s.wi).normalized()
        guard wi.z >= 0, s.wi.z >= 0 else { return nil }
        return SampledDirection(weight: s.weight, wi: wi)
    }
    
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color {
        let frame = Frame(n: normal(uv: uv, p: p))
        let localWo = frame.toLocal(v: wo).normalized()
        let localWi = frame.toLocal(v: wi).normalized()
        
        guard localWi.z >= 0, wi.z >= 0 else { return .zero }
        return material.evaluate(wo: localWo, wi: localWi, uv: uv, p: p)
    }
    
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float {
        let frame = Frame(n: normal(uv: uv, p: p))
        let localWo = frame.toLocal(v: wo).normalized()
        let localWi = frame.toLocal(v: wi).normalized()
        
        guard localWi.z >= 0, wi.z >= 0 else { return 0 }
        return material.pdf(wo: localWo, wi: localWi, uv: uv, p: p)
    }
    
    func hasDelta(uv: Vec2, p: Point3) -> Bool {
        return material.hasDelta(uv: uv, p: p)
    }

    private func normal(uv: Vec2, p: Point3) -> Vec3 {
        let n: Vec3 = normals.get(uv: uv, p: p)
        return (2 * n - Vec3(repeating: 1)).normalized()
    }
}

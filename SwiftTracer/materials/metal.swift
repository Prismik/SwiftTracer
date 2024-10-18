//
//  metal.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-30.
//

import Foundation

/**
 Material with perfectly specular reflections or rough reflections.
 
 # JSON Spec
 
 | Name          | Type      | Usage  |
 | ------------- | --------- | ------ |
 | ks            | Texture   | Color of the surface (probability of light being reflected at a given wavelength). |
 | roughness     | Texture   | Roughness of the reflection. 0 roughness means a perfectly specular (delta), while other values are rough reflections. |
 
*/
final class Metal: Material {
    /// Color of the surface within the [0...1] range (probability of light being reflected at a given wavelength).
    let ks: Texture
    
    /// Roughness of the reflection, within the [0...1] range. 0 roughness means a perfectly specular (delta) reflection,
    /// while other values are used for rough reflections.
    let roughness: Texture

    init(texture: Texture, roughness: Texture) {
        self.ks = texture
        self.roughness = roughness
    }
    
    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection? {
        guard wo.z >= 0 else { return nil }
        
        let specularWi = Vec3(-wo.x, -wo.y, wo.z)
        let roughness: Float = roughness.get(uv: uv, p: p).clamped(0, 1)
        switch roughness {
        case let r where r.isZero:
            return SampledDirection(weight: ks.get(uv: uv, p: p), wi: specularWi.normalized(), pdf: 0)
        case let r where r > 0:
            let frame = Frame(n: specularWi)
            let n = power(roughness: roughness)
            let localLobe = Sample.cosineHemispherePower(sample: sample, power: n)
            let lobe = frame.toWorld(v: localLobe)
            guard lobe.z >= 0 else { return nil }
            let wi = lobe.normalized()
            let pdf = self.pdf(wo: wo, wi: wi, uv: uv, p : p)
            return SampledDirection(weight: ks.get(uv: uv, p: p), wi: lobe.normalized(), pdf: pdf) // TODO Not quite zero for that case
        default:
            return nil // Shouldn't happen
        }
    }
    
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color {
        guard wo.z >= 0 && wi.z >= 0 else { return .zero }
        
        let roughness: Float = roughness.get(uv: uv, p: p).clamped(0, 1)
        guard roughness != 0 else { return .zero }
        
        let specularWi = Vec3(-wo.x, -wo.y, wo.z)
        let n = power(roughness: roughness)
        let ks: Color = ks.get(uv: uv, p: p)
        let a = wi.dot(specularWi).clamped(.ulpOfOne, .pi / 2)
        return ks * (n + 1) / (2 * .pi) * a.pow(n)
    }
    
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float {
        guard wo.z >= 0 && wi.z >= 0 else { return 0 }

        let roughness: Float = roughness.get(uv: uv, p: p).clamped(0, 1)
        guard roughness != 0 else { return 0 }

        let specularWi = Vec3(-wo.x, -wo.y, wo.z)
        let n = power(roughness: roughness)
        let a = wi.dot(specularWi).clamped(.ulpOfOne, .pi / 2)
        return (n + 1) / (2 * .pi) * a.pow(n)
    }
    
    func hasDelta(uv: Vec2, p: Point3) -> Bool {
        return roughness.get(uv: uv, p: p).isZero
    }
    
    private func power(roughness: Float) -> Float {
        return 2 / roughness.pow(2) - 2
    }
}

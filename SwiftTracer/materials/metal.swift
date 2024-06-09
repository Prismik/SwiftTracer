//
//  metal.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-30.
//

import Foundation

final class Metal: Material {
    let hasEmission = false
    let texture: Texture
    let roughness: Texture

    init(texture: Texture, roughness: Texture) {
        self.texture = texture
        self.roughness = roughness
    }
    
    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection? {
        guard wo.z >= 0 else { return nil }
        
        let specularWi = Vec3(-wo.x, -wo.y, wo.z)
        let roughness: Float = roughness.get(uv: uv, p: p)
        switch roughness {
        case let r where r == 0:
            return SampledDirection(weight: texture.get(uv: uv, p: p), wi: specularWi.normalized())
        case let r where r > 0:
            let frame = Frame(n: specularWi)
            let n = power(roughness: roughness)
            let localLobe = Sample.cosineHemispherePower(sample: sample, power: n)
            let lobe = frame.toWorld(v: localLobe)
            guard lobe.z >= 0 else { return nil }
            return SampledDirection(weight: texture.get(uv: uv, p: p), wi: lobe.normalized())
        default:
            return nil // Shouldn't happen
        }
    }
    
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color {
        let wo = wo.normalized()
        let wi = wi.normalized()
        guard wo.z >= 0 && wi.z >= 0 else { return Color() }
        
        let roughness: Float = roughness.get(uv: uv, p: p).clamped(0, 1)
        guard roughness != 0 else { return Color() }
        
        let specularWi = Vec3(-wo.x, -wo.y, wo.z)
        let n = power(roughness: roughness)
        let ks: Color = texture.get(uv: uv, p: p)
        let a = wo.dot(specularWi).clamped(.ulpOfOne, .pi / 2)
        return ks * (n + 1) / (2 * .pi) * a.pow(n)
    }
    
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float {
        let wo = wo.normalized()
        let wi = wi.normalized()
        guard wo.z >= 0 && wi.z >= 0 else { return 0 }

        let roughness: Float = roughness.get(uv: uv, p: p).clamped(0, 1)
        guard roughness != 0 else { return 0 }

        let specularWi = Vec3(-wo.x, -wo.y, wo.z)
        let n = power(roughness: roughness)
        let a = wi.dot(specularWi).clamped(.ulpOfOne, .pi / 2)
        return (n + 1) / (2 * .pi) * pow(a, n)
    }
    
    // TODO Find better name or define properly what a delta is
    func hasDelta(uv: Vec2, p: Point3) -> Bool {
        self.roughness.get(uv: uv, p: p) == 0
    }
    
    func emission(wo: Vec3, uv: Vec2, p: Point3) -> Color {
        Color()
    }
    
    private func power(roughness: Float) -> Float {
        return 2 / roughness.pow(2) - 2
    }
}

//
//  diffuse.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

final class Diffuse: Material {
    let hasEmission = false
    let texture: Texture
    init(texture: Texture) {
        self.texture = texture
    }

    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection? {
        let wo = wo.normalized()
        guard wo.z > 0 else { return nil }
        
        let wi = Sample.cosineHemisphere(sample: sample).normalized()
        let cos = wi.dot(Vec3.unit(.z))
        let albedo: Color = texture.get(uv: uv, p: p)
        let pdf = pdf(wo: wo, wi: wi, uv: uv, p: p)
        let weight = (albedo / Float.pi) * cos / pdf
        
        return SampledDirection(weight: weight, wi: wi)
    }
    
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color {
        let wo = wo.normalized()
        let wi = wi.normalized()
        guard wo.z >= 0 && wi.z >= 0 else { return Color() }
        
        let cos = wi.dot(Vec3.unit(.z))
        return self.texture.get(uv: uv, p: p) / Float.pi * cos
    }
    
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float {
        guard wo.z > 0 else { return 0 }
        return Pdf.cosineHemisphere(v: wi)
    }
    
    func hasDelta(uv: Vec2, p: Point3) -> Bool {
        return false
    }
    
    func emission(wo: Vec3, uv: Vec2, p: Point3) -> Color {
        return Color()
    }
}

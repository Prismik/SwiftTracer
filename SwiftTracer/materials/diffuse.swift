//
//  diffuse.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

final class Diffuse: Material {
    /// Color of the surface (probability of light being reflected at a given wavelength)
    let texture: Texture

    init(texture: Texture) {
        self.texture = texture
    }

    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection? {
        guard wo.z > 0 else { return nil }
        
        let wi = Sample.cosineHemisphere(sample: sample).normalized()
        let cos = wi.dot(Vec3.unit(.z))
        let albedo: Color = texture.get(uv: uv, p: p)
        let pdf = pdf(wo: wo, wi: wi, uv: uv, p: p)
        let weight = (albedo / .pi) * cos / pdf
        // Disregard samples where the weight results in a non finite number
        guard weight.isFinite else {
            return nil
        }
        return SampledDirection(weight: weight, wi: wi)
    }
    
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color {
        let wo = wo.normalized()
        let wi = wi.normalized()
        guard wo.z >= 0 && wi.z >= 0 else { return Color() }
        
        let cos = wi.dot(Vec3.unit(.z))
        return texture.get(uv: uv, p: p) / .pi * cos
    }
    
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float {
        let wo = wo.normalized()
        let wi = wi.normalized()
        guard wo.z > 0 else { return 0 }
        return Pdf.cosineHemisphere(v: wi)
    }
    
    func hasDelta(uv: Vec2, p: Point3) -> Bool {
        return false
    }
}

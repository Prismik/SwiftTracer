//
//  dielectric.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-30.
//

import Foundation

/// Material with glass-like properties. It tends to cause a lot more noise than other materials (partly because of caustics).
final class Dielectric: Material {
    private struct SubstanceGeometry {
        let eta: Float
        let sin: Float
        let cos: Float
    }

    private struct Refraction {
        let normal: Vec3
        let incident: Vec3
        let interior: SubstanceGeometry
        let exterior: SubstanceGeometry
        
        var ratio: Float {
            return interior.eta / exterior.eta
        }

        init(material: Dielectric, wo: Vec3) {
            let inMaterial = wo.z < 0
            let etaI = inMaterial
                ? material.etaInterior
                : material.etaExterior
            let etaT = inMaterial
                ? material.etaExterior
                : material.etaInterior
            let normal = Vec3(0, 0, inMaterial ? -1 : 1)
            let cosThetaI = wo.dot(normal)
            let sinThetaI = (1.0 - cosThetaI * cosThetaI).sqrt().abs()
            let sinThetaT = sinThetaI * (etaI / etaT)
            let cosThetaT = (1 - sinThetaT * sinThetaT).sqrt()
            self.normal = normal
            self.incident = wo
            self.interior = SubstanceGeometry(eta: etaI, sin: sinThetaI, cos: cosThetaI)
            self.exterior = SubstanceGeometry(eta: etaT, sin: sinThetaT, cos: cosThetaT)
        }
        
        func fresnel() -> Float {
            let dif = interior.eta - exterior.eta
            let sum = interior.eta + exterior.eta
            let freznelZero = (dif / sum).pow(2)
            return freznelZero + (1 - freznelZero) * (1 - interior.cos).pow(5)
        }
        
        // TODO Look at refract and reflect of simd
        func reflect() -> Vec3 {
            return Vec3(-incident.x, -incident.y, incident.z).normalized()
        }
        
        func refract() -> Vec3 {
            return (-ratio * incident + (ratio * interior.cos - exterior.cos) * normal).normalized()
        }
    }

    let texture: Texture
    
    /// Interior index of refraction.
    let etaInterior: Float
    
    /// Exterior index of refraction.
    let etaExterior: Float

    init(texture: Texture, etaInterior: Float, etaExterior: Float) {
        self.texture = texture
        self.etaInterior = etaInterior
        self.etaExterior = etaExterior
    }
    
    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection? {
        let r = Refraction(material: self, wo: wo)
        if r.exterior.sin > 1 { // reflect
            return SampledDirection(weight: texture.get(uv: uv, p: p), wi: r.reflect(), pdf: 1.0, eta: etaInterior)
        } else { // tentative refraction
            let rng = sample.x
            let f = r.fresnel()
            let wi = rng < f
                ? r.reflect()
                : r.refract()
            let pdf = rng < f
                ? f
                : 1 - f
            return SampledDirection(weight: texture.get(uv: uv, p: p), wi: wi, pdf: pdf, eta: etaInterior)
        }
    }
    
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color {
        let r = Refraction(material: self, wo: wo)
        if wo.z >= 0 && wi.z >= 0 {
            guard reflectConditionMet(wi: r.reflect(), wo: wo) else { return .zero }
            return texture.get(uv: uv, p: p) * r.fresnel()
        } else {
            guard reflectConditionMet(wi: r.reflect(), wo: wo) else { return .zero }
            return texture.get(uv: uv, p: p) * (1 - r.fresnel())
        }
    }
    
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float {
        let r = Refraction(material: self, wo: wo)
        if wo.z >= 0 && wi.z >= 0 {
            guard reflectConditionMet(wi: r.reflect(), wo: wo) else { return 0 }
            return r.fresnel()
        } else {
            guard reflectConditionMet(wi: r.refract(), wo: wo) else { return 0 }
            return 1 - r.fresnel()
        }
    }
    
    func hasDelta(uv: Vec2, p: Point3) -> Bool {
        return true
    }
    
    private func reflectConditionMet(wi: Vec3, wo: Vec3) -> Bool {
        return (wi.z * wo.z - wi.x * wo.x - wi.y * wo.y - 1.0).abs() < 0.0001
    }
}

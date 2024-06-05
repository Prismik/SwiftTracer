//
//  dielectric.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-30.
//

import Foundation

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
            let sinThetaI = (1.0 - cosThetaI * cosThetaI).squareRoot().abs()
            let sinThetaT = sinThetaI * (etaI / etaT)
            let cosThetaT = (1 - sinThetaT * sinThetaT).squareRoot()
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
        
        func reflect() -> Vec3 {
            return Vec3(-incident.x, -incident.y, incident.z).normalized()
        }
        
        func refract() -> Vec3 {
            return -ratio * incident + (ratio * interior.cos - exterior.cos) * normal
        }
    }

    let hasEmission = false
    let isMedia = false
    let density: Float = 0
    let texture: Texture
    let etaInterior: Float
    let etaExterior: Float
    init(texture: Texture, etaInterior: Float, etaExterior: Float) {
        self.texture = texture
        self.etaInterior = etaInterior
        self.etaExterior = etaExterior
    }
    
    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection? {
        let wo = wo.normalized()
        let r = Refraction(material: self, wo: wo)
        if r.exterior.sin > 1 { // reflect
            return SampledDirection(weight: texture.get(uv: uv, p: p), wi: r.reflect())
        } else { // tentative refraction
            let rng = sample.x
            let wi = rng < r.fresnel()
                ? r.reflect()
                : r.refract()
            return SampledDirection(weight: texture.get(uv: uv, p: p), wi: wi)
        }
    }
    
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color {
        return Color()
    }
    
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float {
        return 0
    }
    
    func hasDelta(uv: Vec2, p: Point3) -> Bool {
        return true
    }
    
    func emission(wo: Vec3, uv: Vec2, p: Point3) -> Color {
        return Color()
    }
}

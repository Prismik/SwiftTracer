//
//  material.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import simd
import Foundation

struct SampledDirection {
    let weight: Color
    
    /// Incident ray
    let wi: Vec3
}

struct AnyMaterial: Decodable {
    let name: String

    enum TypeIdentifier: String, Decodable {
        case diffuse
        case metal
        case dielectric
        case blend
        case normalMap = "normal_map"
    }

    enum CodingKeys: String, CodingKey {
        // Generic
        case type
        case name
        case bump

        // Diffuse
        case albedo
        
        // Metal
        case ks
        case roughness
        
        // Dielectric
        case etaInt = "eta_int"
        case etaExt = "eta_ext"
        
        // Emitter
        case radiance
        
        // Blend
        case alpha
        case m1
        case m2
        
        // Normal map
        case material
        case normals
    }

    let type: TypeIdentifier
    private(set) var wrapped: Material
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(TypeIdentifier.self, forKey: .type)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""

        switch type {
        case .diffuse:
            let texture = try container.decodeIfPresent(Texture.self, forKey: .albedo) ?? .constant(value: Color(repeating: 0.8))
            self.wrapped = Diffuse(texture: texture)
        case .metal:
            let texture = try container.decodeIfPresent(Texture.self, forKey: .ks) ?? .constant(value: Color(repeating: 1))
            do {
                let roughness = try container.decode(Float.self, forKey: .roughness)
                self.wrapped = Metal(texture: texture, roughness: .constant(value: Color(repeating: roughness)))
            } catch {
                let roughness = try container.decodeIfPresent(Texture.self, forKey: .roughness) ?? .constant(value: Color())
                self.wrapped = Metal(texture: texture, roughness: roughness)
            }
        case .dielectric:
            let texture = try container.decodeIfPresent(Texture.self, forKey: .ks) ?? .constant(value: Color(repeating: 1))
            let etaInterior = try container.decodeIfPresent(Float.self, forKey: .etaInt) ?? 1.5
            let etaExterior = try container.decodeIfPresent(Float.self, forKey: .etaExt) ?? 1.0
            self.wrapped = Dielectric(texture: texture, etaInterior: etaInterior, etaExterior: etaExterior)
        case .blend:
            let m1 = try container.decode(AnyMaterial.self, forKey: .m1)
            let m2 = try container.decode(AnyMaterial.self, forKey: .m2)
            let alpha = try container.decodeIfPresent(Texture.self, forKey: .alpha) ?? .constant(value: Color(repeating: 0.5))
            self.wrapped = Blend(m1: m1.wrapped, m2: m2.wrapped, alpha: alpha)
        case .normalMap:
            let anyMaterial = try container.decode(AnyMaterial.self, forKey: .material)
            let normals = try container.decode(Texture.self, forKey: .normals)
            self.wrapped = NormalMap(material: anyMaterial.wrapped, normals: normals)
        }
    }
}

protocol Material {
    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection?
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color
    /// Probability density function of the material
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float
    func hasDelta(uv: Vec2, p: Point3) -> Bool
}

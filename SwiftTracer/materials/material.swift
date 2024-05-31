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
    let wi: Vec3
}

struct AnyMaterial: Decodable {
    let name: String

    enum TypeIdentifier: String, Decodable {
        case diffuse
        case metal
        case dielectric
        case emitter = "diffuse_light"
    }

    enum CodingKeys: String, CodingKey {
        // Generic
        case type
        case name

        // Diffuse
        case albedo
        
        // Metal
        case ks
        case roughness
        
        // Dielectric
        case etaInt = "eta_int"
        case etaExt = "eta_ext"
    }

    let type: TypeIdentifier
    private(set) var wrapped: Material
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(TypeIdentifier.self, forKey: .type)
        self.name = try container.decode(String.self, forKey: .name)
        switch type {
        case .diffuse:
            let texture = try container.decodeIfPresent(Texture<Color>.self, forKey: .albedo) ?? .constant(value: Color(repeating: 1))
            self.wrapped = Diffuse(texture: texture)
        case .metal:
            let texture = try container.decodeIfPresent(Texture<Color>.self, forKey: .ks) ?? .constant(value: Color(repeating: 1))
            let roughness = try container.decode(Texture<Float>.self, forKey: .roughness)
            self.wrapped = Metal(texture: texture, roughness: roughness)
        case .dielectric:
            let texture = try container.decodeIfPresent(Texture<Color>.self, forKey: .ks) ?? .constant(value: Color(repeating: 1))
            let etaInterior = try container.decodeIfPresent(Float.self, forKey: .etaInt) ?? 1.5
            let etaExterior = try container.decodeIfPresent(Float.self, forKey: .etaExt) ?? 1.0
            self.wrapped = Dielectric(texture: texture, etaInterior: etaInterior, etaExterior: etaExterior)
        case .emitter:
            let texture = try container.decodeIfPresent(Texture<Color>.self, forKey: .albedo) ?? .constant(value: Color(repeating: 1))
            self.wrapped = DiffuseLight(texture: texture)
        }
    }
}

protocol Material {
    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection?
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float
    func hasDelta(uv: Vec2, p: Point3) -> Bool
    func emission(wo: Vec3, uv: Vec2, p: Point3) -> Color
    
    var hasEmission: Bool { get }
    var isMedia: Bool { get }
    var density: Float { get }
}

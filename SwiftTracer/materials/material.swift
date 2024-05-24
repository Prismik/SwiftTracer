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
    enum TypeIdentifier: String, Decodable {
        case diffuse
    }

    enum CodingKeys: String, CodingKey {
        // Generic
        case type
        
        // Diffuse
        case albedo
    }

    let type: TypeIdentifier
    private(set) var wrapped: Material
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(TypeIdentifier.self, forKey: .type)
        switch type {
        case .diffuse:
            self.wrapped = Diffuse(texture: try container.decode(Texture<Color>.self, forKey: .albedo))
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

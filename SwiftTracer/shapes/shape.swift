//
//  Shape.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

// TODO Why is it talking about p; investigate
struct EmitterSample {
    /// Position on the light source
    let y: Point3
    /// Normal associated with p
    let n: Vec3
    /// UV coordinates associated with p
    let uv: Vec2
    /// Probability density (in solid angle)
    let pdf: Float
}

struct Intersection {
    /// Intersection distance
    let t: Float
    
    /// Point of intersection TODO is it world or local
    let p: Point3
    
    /// Surface normal
    let n: Vec3
    
    let uv: Vec2
    
    let material: Material
    
    let shape: Shape
}

/// Box type for protocol of shape. Material gets decoded and assigned during unwraping.
struct AnyShape: Decodable {
    enum TypeIdentifier: String, Codable {
        case sphere
        case quad
    }

    enum CodingKeys: String, CodingKey {
        // Generic
        case transform
        case material
        case type

        // Sphere
        case radius
        case solidAngle
        
        // Quad
        case size
    }

    let type: TypeIdentifier
    let material: AnyMaterial.TypeIdentifier
    private var wrapped: Shape

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(TypeIdentifier.self, forKey: .type)
        let transform = try container.decodeIfPresent(Transform.self, forKey: .transform) ?? Transform(m: Mat4())
        self.material = try container.decode(AnyMaterial.TypeIdentifier.self, forKey: .material)
        switch type {
        case .sphere:
            self.wrapped = Sphere(
                r: try container.decode(Float.self, forKey: .radius),
                t: transform,
                solidAngle: try container.decodeIfPresent(Bool.self, forKey: .solidAngle) ?? false
            )
        case .quad:
            // TODO Support rectangle
            let size = try container.decode(Float.self, forKey: .size)
            self.wrapped = Quad(
                halfSize: Vec2(size / 2, size / 2),
                transform: transform
            )
        }
    }
    
    func unwrapped(materials: [AnyMaterial.TypeIdentifier: Material]) -> Shape {
        var shape = self.wrapped
        shape.material = materials[material]
        return shape
    }
}

protocol Shape {
    func hit(r: Ray) -> Intersection?
    func aabb() -> AABB
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample
    /// For groups, provide the appropriate shape
    func pdfDirect(shape: Shape, p: Point3, y: Point3, n: Vec3) -> Float // TODO What is y
    
    var material: Material! { get set }
}

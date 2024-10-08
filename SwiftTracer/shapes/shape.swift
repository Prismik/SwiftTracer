//
//  Shape.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation
import simd

struct EmitterSample {
    /// Position on the light source
    let y: Point3
    /// Normal associated with y
    let n: Vec3
    /// UV coordinates associated with y
    let uv: Vec2
    /// Probability density (in solid angle)
    let pdf: Float
    /// Associated shape
    let shape: Shape
}

struct Intersection {
    /// Intersection distance
    let t: Float
    
    /// Point of intersection
    let p: Point3
    
    /// Surface normal
    let n: Vec3
    
    let tan: Vec3

    let bitan: Vec3
    
    let uv: Vec2
    
    let shape: Shape
    
    var hasEmission: Bool {
        return shape.light != nil
    }
}

/// Box type for ``Shape`` protocol that allows to decode shapes in a type agnostic way. Material and lights gets decoded and assigned during unwraping.
struct AnyShape: Decodable {
    enum TypeIdentifier: String, Codable {
        case sphere
        case quad
        case triangle
        case mesh
    }

    enum CodingKeys: String, CodingKey {
        // Generic
        case transform
        case material
        case light
        case type

        // Sphere
        case radius
        case solidAngle
        
        // Quad
        case size
        
        // Triangle
        case positions
        case normals

        // Mesh
        case filename
    }

    let type: TypeIdentifier
    let material: String
    let light: String
    private(set) var wrapped: Shape

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(TypeIdentifier.self, forKey: .type)
        // TODO Make available to other objects
        let transform = try container.decodeIfPresent(Transform.self, forKey: .transform) ?? Transform(m: Mat4.identity())
        self.material = try container.decodeIfPresent(String.self, forKey: .material) ?? ""
        self.light = try container.decodeIfPresent(String.self, forKey: .light) ?? ""
        switch type {
        case .sphere:
            self.wrapped = Sphere(
                r: try container.decodeIfPresent(Float.self, forKey: .radius) ?? 1,
                t: transform,
                solidAngle: try container.decodeIfPresent(Bool.self, forKey: .solidAngle) ?? true
            )
        case .quad:
            let size: Vec2
            do {
                let value = try container.decode(Float.self, forKey: .size)
                size = Vec2(value / 2, value / 2)
            } catch {
                let value = try container.decode(Vec2.self, forKey: .size)
                size = value / 2
            }

            self.wrapped = Quad(
                halfSize: size,
                transform: transform
            )
        case .mesh:
            let filename = try container.decode(String.self, forKey: .filename)
            #if os(Linux)
            let url = URL(fileURLWithPath: "SwiftTracer/assets/mesh/\(filename).obj")
            #else
            let url = URL(fileURLWithPath: "assets/\(filename).obj")
            #endif

            let mesh = Mesh(filename: url, transform: transform)
            let group = ShapeGroup()
            for id in 0 ..< mesh.facePositionIndexes.count {
                group.add(shape: Triangle(faceId: id, mesh: mesh))
            }
            self.wrapped = group
        case .triangle:
            let positions = try container.decode([Vec3].self, forKey: .positions)
            let normals = try container.decodeIfPresent([Vec3].self, forKey: .normals) ?? []
            let mesh = Mesh(positions: positions, normals: normals)
            self.wrapped = Triangle(faceId: 0, mesh: mesh)
        }
    }
    
    /// Unwraps a shape by trying to associate a material identifier with a `Material` instance, or a light identifier with a `Light` instance.
    func unwrapped(materials: [String: Material], lights: [String: Light]) -> Shape {
        let shape = self.wrapped
        if material.isEmpty, let light = lights[light] as? AreaLight {
            shape.light = light
        } else {
            shape.material = materials[material]
        }
        
        return shape
    }
}

/// Object that can be physically hit by a ray.
protocol Intersecting {
    func hit(r: Ray) -> Intersection?
}

/// Geometric primitive that lives within a scene.
protocol Shape: AnyObject, Intersecting {
    /// Computed bounding box.
    func aabb() -> AABB
    /// Samples a point on the shape.
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample
    /// Probability density function for radiance emition of an area light.
    func pdfDirect(shape: Shape, p: Point3, y: Point3, n: Vec3) -> Float
    
    /// Mutually exclusive with light
    var material: Material! { get set }
    var area: Float { get }
    /// For area lights, their parent shape will hold a weak reference to them.
    var light: Light! { get set }
}

protocol ShapeAggregate: Intersecting {
    func aabb() -> AABB
    func add(shape: Shape)
    func build()
}

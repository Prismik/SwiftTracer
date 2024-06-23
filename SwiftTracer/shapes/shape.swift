//
//  Shape.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation
import simd

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
    let shape: Shape
}

struct Intersection {
    /// Intersection distance
    let t: Float
    
    /// Point of intersection TODO is it world or local
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

/// Box type for protocol of shape. Material gets decoded and assigned during unwraping.
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
        let transform: Transform
        if let transforms = try? container.decode([Transform].self, forKey: .transform) {
            var m = Mat4.identity()
            for t in transforms {
                m = t.m * m
            }
            
            transform = Transform(m: m)
        }
        else  {
            transform = try container.decodeIfPresent(Transform.self, forKey: .transform) ?? Transform(m: Mat4.identity())
        }
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
            guard let url = Bundle.main.url(forResource: filename, withExtension: "obj", subdirectory: "assets") else {
                fatalError("Trying to load obj that does not exist")
            }
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
    
    /// Unwraps a shape by trying to associate a material identifier with a Material instance
    func unwrapped(materials: [String: Material], lights: [String: Light]) -> Shape {
        let shape = self.wrapped
        if material.isEmpty, let light = lights[light] as? AreaLight {
            if let group = shape as? ShapeGroup {
                for triangle in group.shapes {
                    triangle.light = light
                    light.shape = triangle
                }
            }
            light.shape = shape
            shape.light = light
        } else {
            shape.material = materials[material]
        }
        
        return shape
    }
}

protocol Intersecting {
    func hit(r: Ray) -> Intersection?
}

protocol Shape: AnyObject, Intersecting {
    func aabb() -> AABB
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample
    /// For groups, provide the appropriate shape
    func pdfDirect(shape: Shape, p: Point3, y: Point3, n: Vec3) -> Float // TODO What is y
    
    /// Mutually exclusive with light
    var material: Material! { get set }
    var area: Float { get }
    /// For area lights, their parent shape will hold a weak reference to them.
    var light: Light! { get set }
}

protocol ShapeAggregate: Intersecting {
    func add(shape: Shape)
    func build()
}

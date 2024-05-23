//
//  Shape.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

/// Box type for protocol of shape. Material gets decoded and assigned during unwraping.
struct AnyShape: Decodable {
    let type: String
    let material: String
    static func unwrap(shape data: Data, using decoder: JSONDecoder, materials: [String: Material]) throws -> Shape {
        let box = try decoder.decode(AnyShape.self, from: data)
        guard let material = materials[box.material] else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid material in \(box.type)"))
        }
        switch box.type {
        case "sphere":
            let sphere = try decoder.decode(Sphere.self, from: data)
            sphere.material = material
            return sphere
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Invalid shape type")
            )
        }
    }
}

protocol Shape: Decodable {
    func hit(r: Ray) -> Intersection?
    func aabb() -> AABB
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample
    func pdfDirect(p: Point3, y: Point3, n: Vec3) -> Float
    
    var material: Material! { get }
}

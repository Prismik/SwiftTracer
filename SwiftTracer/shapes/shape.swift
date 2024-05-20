//
//  Shape.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

protocol Shape {
    func hit(r: Ray) -> Intersection?
    func aabb() -> AABB
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample
    func pdfDirect(p: Point3, y: Point3, n: Vec3) -> Float
    
    var material: Material { get }
}

extension Shape {
    static func from(json: Data) -> Shape? {
        return nil
    }
}

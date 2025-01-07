//
//  shapeGroup.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import Foundation

final class ShapeGroup: ShapeAggregate {
    var shapes: [Shape] = []
    var aabbs: [AABB] = []
    var lightIndexes: [Int] = []
    var material: Material!
    
    private var bounds: AABB = AABB()
    unowned var light: Light!

    func hit(r: Ray) -> Intersection? {
        Scene.NB_INTERSECTION += 1
        var intersection: Intersection? = nil
        for (i, shape) in shapes.enumerated() {
            let aabb = aabbs[i]
            if aabb.hit(r: r) != nil, let its = shape.hit(r: r), its.t < r.t.max {
                r.t = r.t.with(max: its.t)
                intersection = its
            }
        }
        
        return intersection
    }

    func add(shape: Shape) {
        let shapeAabb = shape.aabb()
        aabbs.append(shapeAabb)
        shapes.append(shape)
        bounds = bounds.merge(with: shapeAabb)
    }
    
    func build() { }
}


// Extending group as a shape so we can wrap a mesh into a shape group temporarily during decoding
extension ShapeGroup: Shape {
    func aabb() -> AABB {
        return self.bounds
    }
    
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample {
        fatalError("Invalid call of sampleDirect on ShapeGroup! Call on triangles instead.")
    }
    
    func pdfDirect(shape: any Shape, p: Point3, y: Point3, n: Vec3) -> Float {
        fatalError("Invalid call of pdfDirect on ShapeGroup! Call on triangles instead.")
    }
    
    var area: Float {
        fatalError("Invalid call of area on ShapeGroup! Call on triangles instead.")
    }
}

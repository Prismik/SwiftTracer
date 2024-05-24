//
//  shapeGroup.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import Foundation

final class ShapeGroup: Shape {
    var shapes: [Shape] = []
    var aabbs: [AABB] = []
    var lightIndexes: [Int] = []
    var material: Material!

    func hit(r: Ray) -> Intersection? {
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
    
    func aabb() -> AABB {
        var aabb = AABB()
        for shapeAabb in aabbs {
            aabb.extend(with: shapeAabb.min)
            aabb.extend(with: shapeAabb.max)
        }
        
        return aabb.sanitized()
    }
    
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample {
        let n = Float(lightIndexes.count)
        var rng = sample
        let j = floor(sample.x * n)
        let idx = lightIndexes[Int(j)]
        rng.x = sample.x * n - j
        let shape = shapes[idx]
        let e = shape.sampleDirect(p: p, sample: rng)
        let pdf = self.pdfDirect(shape: shape, p: p, y: e.y, n: e.n)
        return EmitterSample(
            y: e.y,
            n: e.n,
            uv: e.uv,
            pdf: pdf
        )
    }
    
    func pdfDirect(shape: Shape, p: Point3, y: Point3, n: Vec3) -> Float {
        let marginal: Float = (1.0 / Float(lightIndexes.count))
        let conditional = shape.pdfDirect(shape: shape, p: p, y: y, n: n)
        return marginal * conditional
    }
    
    private func add(shape: Shape) {
        if shape.material.hasEmission {
            lightIndexes.append(shapes.count)
        }
        
        aabbs.append(shape.aabb())
        shapes.append(shape)
    }
}

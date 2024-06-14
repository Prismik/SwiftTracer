//
//  quad.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import Foundation

final class Quad: Shape {
    let halfSize: Vec2
    let transform: Transform
    var material: Material!
    
    init(halfSize: Vec2, transform: Transform) {
        self.halfSize = halfSize
        self.transform = transform
    }
    
    func hit(r: Ray) -> Intersection? {
        Scene.NB_INTERSECTION += 1
        let ray = transform.inverse().ray(r)
        
        // If the ray direction is parallel to the plane, no intersections happen
        guard ray.d.z != 0 else { return nil }
        
        // Intersection distance
        let t = -ray.o.z / ray.d.z
        guard ray.t.range.contains(t) else { return nil }
        
        let p = ray.pointAt(t: t)
        // Check if the x and y component of the intersection point is inside the quad
        guard p.x.abs() <= halfSize.x && p.y.abs() <= halfSize.y else { return nil }

        return Intersection(
            t: t,
            p: transform.point(Point3(p.x, p.y, 0)), // Force the point to be on the plane
            n: transform.normal(Vec3.unit(.z)).normalized(),
            tan: transform.vector(Vec3.unit(.x)).normalized(),
            bitan: transform.vector(Vec3.unit(.y)).normalized(),
            uv: uv(p: p),
            material: material,
            shape: self
        )
    }
    
    func aabb() -> AABB {
        var result = AABB()
        let min = transform.point(Point3(-halfSize.x, -halfSize.y, -1e-2))
        let max = transform.point(Point3(halfSize.x, halfSize.y, 1e-2))
        result.extend(with: min)
        result.extend(with: max)
        return result.sanitized()
    }
    
    func sampleDirect(p: Point3, n: Vec3, sample: Vec2) -> EmitterSample {
        let n = transform.normal(Vec3.unit(.z)).normalized()
        var y = Point3(
            sample.x * halfSize.x * 2 - halfSize.x,
            sample.y * halfSize.y * 2 - halfSize.y,
            0
        )
        y = transform.point(y)
        return EmitterSample(y: y, n: n, uv: uv(p: p), pdf: pdfDirect(shape: self, p: p, y: y, n: n), shape: self)
    }
    
    func pdfDirect(shape: Shape, p: Point3, y: Point3, n: Vec3) -> Float {
        let sqDistance = y.distance2(p)
        let wi = (p - y).normalized()
        let cos = n.dot(wi).abs()
        let area = halfSize.x * halfSize.y * 4
        return sqDistance / (cos * area)
    }
    
    private func uv(p: Point3) -> Vec2 {
        return (Vec2(p.x, p.y) + halfSize) / (halfSize * 2)
    }
}

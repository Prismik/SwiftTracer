//
//  Sphere.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

final class Sphere: Shape {
    let radius: Float
    let transform: Transform
    var material: Material!
    let solidAngle: Bool
    let center: Point3

    init(r: Float, t: Transform, solidAngle: Bool) {
        self.radius = r
        self.transform = t
        self.center = Point3(0, 0, 0)
        self.solidAngle = solidAngle
    }

    func hit(r: Ray) -> Intersection? {
        Scene.NB_INTERSECTION += 1
        
        let ray = transform.inverse().ray(r)
        let o = ray.o - center
        let a = ray.d.dot(ray.d)
        let b = 2 * ray.d.dot(o)
        let c = o.dot(o) - radius * radius
        let discriminant = b * b - 4 * a * c
        var t: Float = 0
        switch(discriminant) {
        case let x where x < 0: // No roots
            return nil
        case let x where x == 0: // One root
            t = -b / (2 * a)
        case let x where x > 0: // Two roots
            var root = (-b - discriminant.squareRoot()) / (2 * a)
            let validRange = ray.t.min..<ray.t.max
            if !validRange.contains(root) {
                root = (-b + discriminant.squareRoot()) / (2 * a)
                if !validRange.contains(root) {
                    return nil
                }
            }
            
            t = root
        default:
            return nil // TODO better handling of impossible case
        }
        
        let p = ray.pointAt(t: t)
        let n = (p - center) / radius
        
        return Intersection(
            t: t,
            p: transform.point(p),
            n: transform.normal(n).normalized(),
            uv: uv(center: center, p: p),
            material: material,
            shape: self
        )
    }
    
    func aabb() -> AABB {
        var result = AABB()
        
        let r = self.radius
        let p000 = transform.point(Point3(repeating: -r));
        let p001 = transform.point(Point3(-r, -r, r));
        let p010 = transform.point(Point3(-r, r, -r));
        let p100 = transform.point(Point3(r, -r, -r));
        let p011 = transform.point(Point3(-r, r, r));
        let p110 = transform.point(Point3(r, r, -r));
        let p101 = transform.point(Point3(r, -r, r));
        let p111 = transform.point(Point3(repeating: r));
        for p in [p000, p001, p010, p100, p011, p110, p101, p111] {
            result.extend(with: p);
         }

        return result.sanitized()
    }
    
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample {
        return solidAngle
            ? sampleSolidAngle(p: p, sample: sample)
            : sampleSpherical(p: p, sample: sample)
    }
    
    func pdfDirect(shape: Shape, p: Point3, y: Point3, n: Vec3) -> Float {
        return solidAngle
            ? pdfSolidAngle(p: p)
            : pdfSpherical(p: p, y: y, n: n)
    }
    
    private func uv(center: Point3, p: Point3) -> Vec2 {
        let v = (p - center).normalized()
        let theta = atan2(v.y, v.x)
        let phi = v.z.acos()
        return Vec2(
            (.pi + theta) / (2 * .pi),
            (.pi - phi) / .pi
        )
    }
    
    private func sampleSpherical(p: Point3, sample: Vec2) -> EmitterSample {
        let uniform = Sample.spherical(sample: sample)
        var y = uniform * radius
        y = transform.point(Point3(y))
        let n = transform.normal(uniform.normalized()).normalized()
        let center = transform.point(Point3())
        
        return EmitterSample(
            y: y,
            n: n,
            uv: uv(center: center, p: p),
            pdf: pdfDirect(shape: self, p: p, y: y, n: n),
            shape: self
        )
    }
    
    private func sampleSolidAngle(p: Point3, sample: Vec2) -> EmitterSample {
        let center = transform.point(Point3())
        let sqDistance = p.distance2(center)
        guard sqDistance > radius.pow(2) else { return sampleSpherical(p: p, sample: sample) }
        
        let thetaMax = (1 - (radius.pow(2) / sqDistance)).squareRoot().acos()
        let uniform = Sample.cone(sample: sample, thetaMax: thetaMax)
        let frame = Frame(n: (center - p).normalized())
        if let hit = self.hit(r: Ray(origin: p, direction: frame.toWorld(v: uniform))) {
            return EmitterSample(y: hit.p, n: hit.n, uv: uv(center: center, p: p), pdf: pdfSolidAngle(p: p), shape: self)
        } else {
            fatalError("Something went wrong when sampling the sphere with solid angle!")
        }
        
    }
    
    private func pdfSpherical(p: Point3, y: Point3, n: Vec3) -> Float {
        let sqDistance = y.distance2(p)
        let wi = (p - y).normalized()
        let cos = abs(n.dot(wi))
        let area = 4 * Float.pi * pow(radius, 2)
        return sqDistance / (cos * area)
    }
    
    private func pdfSolidAngle(p: Point3) -> Float {
        let center = transform.point(Point3())
        let d = p.distance(center)
        let cosThetaMax = (d.pow(2) - radius.pow(2)).squareRoot() / d
        let area = 2 * .pi * (1 - cosThetaMax)
        return 1 / area
    }
}

//
//  Sphere.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

class Sphere: Shape {
    let radius: Float
    let transform: Transform
    let material: Material
    let solidAngle: Bool
    let center: Point3

    init(data: Data, material: Material) {
        self.radius = 1.0 // todo load from json
        self.transform = Transform(m: Mat4()) // todo load from json
        self.center = Point3(0, 0, 0)
        self.material = material
        self.solidAngle = false // todo solid angle
    }

    func hit(r: Ray) -> Intersection? {
        // NUMBER_INTERSECTIONS.with(|f| *f.borrow_mut() += 1);
        
        let ray = self.transform.inverse().ray(r)
        let o = ray.o - self.center
        let a = ray.d.dot(ray.d)
        let b = 2 * ray.d.dot(o)
        let c = o.dot(o) - self.radius * self.radius
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
        
        return nil
    }
    
    func aabb() -> AABB {
        var result = AABB()
        
        let r = self.radius
        let p000 = self.transform.point(Point3(repeating: -r));
        let p001 = self.transform.point(Point3(-r, -r, r));
        let p010 = self.transform.point(Point3(-r, r, -r));
        let p100 = self.transform.point(Point3(r, -r, -r));
        let p011 = self.transform.point(Point3(-r, r, r));
        let p110 = self.transform.point(Point3(r, r, -r));
        let p101 = self.transform.point(Point3(r, -r, r));
        let p111 = self.transform.point(Point3(repeating: r));
        for p in [p000, p001, p010, p100, p011, p110, p101, p111] {
            result.extend(with: p);
            //result.extend(p + self.center_vec);
            //result.extend(p - self.center_vec);
         }

        return result.sanitized()
    }
    
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample {
        return self.solidAngle
            ? self.sampleSolidAngle(p: p, sample: sample)
            : self.sampleSpherical(p: p, sample: sample)
    }
    
    func pdfDirect(p: Point3, y: Point3, n: Vec3) -> Float {
        return self.solidAngle
            ? self.pdfSolidAngle()
            : self.pdfSpherical(p: p, y: y, n: n)
    }
    
    private func uv(center: Point3, p: Point3) -> Vec2 {
        let v = p - center
        var phi = atan2(v.y, v.x)
        let theta = acos(v.z / self.radius)
        if phi < 0 {
            phi += 2 * Float.pi
        }
        
        let invPi = 1 / Float.pi
        return Vec2(phi * (0.8 * invPi), theta * invPi)
    }
    
    private func sampleSpherical(p: Point3, sample: Vec2) -> EmitterSample {
        let uniform = Vec3.sphericalSampleFrom(sample: sample)
        var y = uniform * self.radius
        y = self.transform.point(Point3(y))
        let n = self.transform.normal(uniform.normalized()).normalized()
        let center = self.transform.point(Point3())
        
        return EmitterSample(
            y: y,
            n: n,
            uv: self.uv(center: center, p: p),
            pdf: self.pdfDirect(p: p, y: y, n: n)
        )
    }
    
    private func sampleSolidAngle(p: Point3, sample: Vec2) -> EmitterSample {
        // TODO
        return EmitterSample(y: Point3(), n: Vec3(), uv: Vec2(), pdf: 0)
    }
    
    private func pdfSpherical(p: Point3, y: Point3, n: Vec3) -> Float {
        let sqDistance = y.distance2(p)
        let wi = (p - y).normalized()
        let cos = abs(n.dot(wi))
        let area = 4 * Float.pi * pow(self.radius, 2)
        return sqDistance / (cos * area)
    }
    
    private func pdfSolidAngle() -> Float {
        return 0
    }
}

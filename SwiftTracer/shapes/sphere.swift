//
//  Sphere.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

// TODO Get rid of center dependency
final class Sphere: Shape {
    let radius: Float
    let transform: Transform
    var material: Material!
    let solidAngle: Bool
    var light: Light!
    
    var area: Float { return 4 * Float.pi * pow(radius, 2) } // TODO Check how this plays with solid angle sampling
    
    init(r: Float, t: Transform, solidAngle: Bool) {
        self.radius = r
        self.transform = t
        self.solidAngle = solidAngle
    }

    func hit(r: Ray) -> Intersection? {
        Scene.NB_INTERSECTION += 1
        
        let ray = transform.inverse().ray(r)
        let o = ray.o - Point3()
        let a = ray.d.dot(ray.d)
        let b = 2 * ray.d.dot(o)
        let c = o.dot(o) - radius * radius
        let discriminant = b * b - 4 * a * c
        var t: Float = 0
        switch(discriminant) {
        case let x where x.isLess(than: 0): // No roots
            return nil
        case let x where x.isZero: // One root
            t = -b / (2 * a)
        default: // Two roots
            var root = (-b - discriminant.sqrt()) / (2 * a)
            let validRange = ray.t.min ..< ray.t.max
            if !validRange.contains(root) {
                root = (-b + discriminant.sqrt()) / (2 * a)
                if !validRange.contains(root) {
                    return nil
                }
            }
            
            t = root
        }
        
        let p = ray.pointAt(t: t)
        let n = (p - Point3()) / radius
        
        let vs: Vec3
        let vt: Vec3
        
        let theta = (p.z / radius).acos()
        let dpdu = transform.vector(Vec3(-p.y, p.x, 0) * 2 * .pi)
        var dpdv: Vec3
        let zRad = (p.x * p.x + p.y * p.y).sqrt()
        if zRad > 0 {
            let zRadInv = 1 / zRad
            let cosPhi = p.x * zRadInv
            let sinPhi = p.y * zRadInv
            dpdv = Vec3(
                p.z * cosPhi,
                p.z * sinPhi,
                -theta.sin() * radius
            ) * .pi
            dpdv = transform.vector(dpdv)
            vs = dpdu.normalized()
            vt = dpdv.normalized()
        } else {
            let cosPhi: Float = 0
            let sinPhi: Float = 0
            dpdv = Vec3(
                p.z * cosPhi,
                p.z * sinPhi,
                -theta.sin() * radius
            ) * .pi
            dpdv = transform.vector(dpdv)
            if n.x.abs() > n.y.abs() {
                let invLen = 1 / (n.x * n.x + n.z * n.z).sqrt()
                vt = Vec3(n.z * invLen, 0, -n.x * invLen)
            } else {
                let invLen = 1 / (n.y * n.y + n.z * n.z).sqrt()
                vt = Vec3(0, n.z * invLen, -n.y * invLen)
            }
            vs = vt.cross(n)
        }

        return Intersection(
            t: t,
            p: transform.point(p),
            n: transform.normal(n).normalized(),
            tan: vs.normalized(),
            bitan: vt.normalized(),
            uv: uv(center: Point3(), p: p),
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
        
        let thetaMax = (1 - (radius.pow(2) / sqDistance)).sqrt().acos()
        let uniform = Sample.cone(sample: sample, thetaMax: thetaMax)
        let frame = Frame(n: (center - p).normalized())
        if let hit = self.hit(r: Ray(origin: p, direction: frame.toWorld(v: uniform).normalized())) {
            return EmitterSample(y: hit.p, n: hit.n, uv: uv(center: center, p: p), pdf: pdfSolidAngle(p: p), shape: self)
        } else {
            // Previously FatalError
            return sampleSpherical(p: p, sample: sample)
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
        let cosThetaMax = (d.pow(2) - radius.pow(2)).sqrt() / d
        let area = 2 * .pi * (1 - cosThetaMax)
        return 1 / area
    }
}

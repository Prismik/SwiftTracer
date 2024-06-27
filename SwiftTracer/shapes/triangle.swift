//
//  triangle.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-01.
//

import Foundation

final class Triangle: Shape {
    var material: Material! {
        get { return mesh.material }
        set { mesh.material = newValue }
    }
    
    var area: Float {
        let (p0, p1, p2) = vertices
        let edge1 = p1 - p0
        let edge2 = p2 - p0
        return edge1.cross(edge2).length / 2
    }
    
    // TODO Memory handling of cross-related references
    unowned var mesh: Mesh
    
    unowned var light: Light! {
        get { return mesh.light }
        set { mesh.light = newValue }
    }

    private let vertices: (Point3, Point3, Point3)
    private let normals: (Vec3, Vec3, Vec3)?
    private var uvCoordinates: (Vec2, Vec2, Vec2)?
    
    init(
        mesh: Mesh,
        vertices: (Vec3, Vec3, Vec3),
        normals: (Vec3, Vec3, Vec3)? = nil,
        uvs: (Vec2, Vec2, Vec2)? = nil
    ) {
        self.vertices = vertices
        self.normals = normals
        self.uvCoordinates = uvs
        self.mesh = mesh
    }

    func hit(r: Ray) -> Intersection? {
        Scene.NB_INTERSECTION += 1
        
        let epsilon: Float = 0.0000001
        let (p0, p1, p2) = vertices
        let edge1 = p1 - p0
        let edge2 = p2 - p0
        
        let pvec = r.d.cross(edge2)
        let det = edge1.dot(pvec)
        guard det.abs() >= epsilon else { return nil }
        
        let invDet: Float = 1 / det
        
        let tvec = r.o - p0
        let u = tvec.dot(pvec) * invDet
        guard (0 ... 1).contains(u) else { return nil }
        
        let qvec = tvec.cross(edge1)
        let v = r.d.dot(qvec) * invDet
        guard v >= 0 && u + v <= 1 else { return nil }
        
        let t = edge2.dot(qvec) * invDet
        guard t >= epsilon && t >= r.t.min && t <= r.t.max else { return nil }
        
        let p = (1 - u - v) * p0
            + u * p1
            + v * p2
        
        let n: Vec3
        if let (n0, n1, n2) = normals {
            n = ((1.0 - u - v) * n0 + u * n1 + v * n2).normalized()
        } else {
            n = edge1.cross(edge2).normalized()
        }
        
        // TODO Tangents + Bitangents
        
        
        return Intersection(
            t: t,
            p: p,
            n: n,
            tan: Vec3(),
            bitan: Vec3(),
            uv: uv(coordinates: (1 - u - v, u, v)),
            shape: self
        )
    }
    
    func aabb() -> AABB {
        let (p0, p1, p2) = vertices
        var result = AABB()
        result.extend(with: p0)
        result.extend(with: p1)
        result.extend(with: p2)
        
        return result.sanitized()
    }
    
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample {
        let (p0, p1, p2) = vertices
        let edge1 = p1 - p0
        let edge2 = p2 - p0
        let (u, v) = sample.sum() > 1
            ? (1 - sample.x, 1 - sample.y)
            : (sample.x, sample.y)
        
        let n: Vec3
        if let (n0, n1, n2) = normals {
            n = ((1.0 - u - v) * n0 + u * n1 + v * n2).normalized()
        } else {
            n = edge1.cross(edge2).normalized()
        }
        
        let y = (1 - u - v) * p0
            + u * p1
            + v * p2
        
        return EmitterSample(y: y, n: n, uv: uv(coordinates: (1 - u - v, u, v)), pdf: pdfDirect(shape: self, p: p, y: y, n: n), shape: self)
    }
    
    func pdfDirect(shape: Shape, p: Point3, y: Point3, n: Vec3) -> Float {
        let sqDistance = y.distance2(p)
        let wi = (p - y).normalized()
        let cos = n.dot(wi).abs()
        return sqDistance / (cos * area)
    }
    
    private func uv(coordinates coords: (Float, Float, Float)) -> Vec2 {
        let (a, b, c) = coords
        let (uv0, uv1, uv2) = uvCoordinates ?? (Vec2(0,0), Vec2(1, 0), Vec2(1, 1))
        return a * uv0 + b * uv1 + c * uv2
    }
}

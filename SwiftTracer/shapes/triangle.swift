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
    
    let faceId: Int
    
    // TODO Memory handling of cross-related references
    let mesh: Mesh

    private var vertices: (Point3, Point3, Point3) {
        let indexes = mesh.facePositionIndexes[faceId]
        let p0 = mesh.positions[Int(indexes.x)]
        let p1 = mesh.positions[Int(indexes.y)]
        let p2 = mesh.positions[Int(indexes.z)]
        
        return (p0, p1, p2)
    }

    private var normals: (Vec3, Vec3, Vec3)? {
        guard mesh.hasNormals else { return nil }
        let indexes =  mesh.faceNormalIndexes[faceId]
        let n0 = mesh.normals[Int(indexes.x)]
        let n1 = mesh.normals[Int(indexes.y)]
        let n2 = mesh.normals[Int(indexes.z)]
        
        return (n0, n1, n2)
    }

    private var tangents: (Vec3, Vec3, Vec3)? {
        guard mesh.hasTangents else { return nil }
        let indexes = mesh.faceTangentIndexes[faceId]
        let t0 = mesh.tangents[Int(indexes.x)]
        let t1 = mesh.tangents[Int(indexes.y)]
        let t2 = mesh.tangents[Int(indexes.z)]
        
        return t0.length != 0 && t1.length != 0 && t2.length != 0
            ? (t0, t1, t2)
            : nil
    }
    
    private var uvCoordinates: (Vec2, Vec2, Vec2)? {
        guard mesh.hasUvs else { return nil }
        let indexes =  mesh.faceUvIndexes[faceId]
        let uv0 = mesh.uvs[Int(indexes.x)]
        let uv1 = mesh.uvs[Int(indexes.y)]
        let uv2 = mesh.uvs[Int(indexes.z)]
        
        return (uv0, uv1, uv2)
    }

    init(faceId: Int, mesh: Mesh) {
        self.faceId = faceId
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
            n = (1.0 - u - v) * n0 + u * n1 + v * n2
        } else {
            n = edge1.cross(edge2).normalized()
        }
        
        // TODO Tangents + Bitangents
        
        return Intersection(t: t, p: p, n: n, uv: uv(coordinates: (1 - u - v, u, v)), material: mesh.material, shape: self)
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
            n = (1.0 - u - v) * n0 + u * n1 + v * n2
        } else {
            n = edge1.cross(edge2).normalized()
        }
        
        let y = (1 - u - v) * p0
            + u * p1
            + v * p2
        
        return EmitterSample(y: y, n: n, uv: uv(coordinates: (1 - u - v, u, v)), pdf: pdfDirect(shape: self, p: p, y: y, n: n))
    }
    
    func pdfDirect(shape: Shape, p: Point3, y: Point3, n: Vec3) -> Float {
        let sqDistance = y.distance2(p)
        let wi = (p - y).normalized()
        let cos = n.dot(wi).abs()
        let (p0, p1, p2) = vertices
        let edge1 = p1 - p0
        let edge2 = p2 - p0
        let area = edge1.cross(edge2).length / 2
        return sqDistance / (cos * area)
    }
    
    private func uv(coordinates coords: (Float, Float, Float)) -> Vec2 {
        let (a, b, c) = coords
        let (uv0, uv1, uv2) = uvCoordinates ?? (Vec2(0,0), Vec2(1, 0), Vec2(1, 1))
        return a * uv0 + b * uv1 + c * uv2
    }
}

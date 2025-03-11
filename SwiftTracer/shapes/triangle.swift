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
    
    let area: Float
    
    let faceId: Int
    
    // TODO Memory handling of cross-related references
    let mesh: Mesh
    unowned var light: Light!

    private let vertices: (Point3, Point3, Point3)
    private let normals: (Vec3, Vec3, Vec3)?
    private let tangents: (Vec3, Vec3, Vec3)?
    private let uvCoordinates: (Vec2, Vec2, Vec2)?
    private let edge1: Vec3
    private let edge2: Vec3

    init(faceId: Int, mesh: Mesh) {
        self.faceId = faceId
        self.mesh = mesh
        
        // Vertices
        let vertexIndexes = mesh.facePositionIndexes[faceId]
        let p0 = mesh.positions[Int(vertexIndexes.x)]
        let p1 = mesh.positions[Int(vertexIndexes.y)]
        let p2 = mesh.positions[Int(vertexIndexes.z)]
        self.vertices = (p0, p1, p2)
        self.edge1 = p1 - p0
        self.edge2 = p2 - p0
    
        // Normals
        if mesh.hasNormals {
            let normalIndexes =  mesh.faceNormalIndexes[faceId]
            let n0 = mesh.normals[Int(normalIndexes.x)]
            let n1 = mesh.normals[Int(normalIndexes.y)]
            let n2 = mesh.normals[Int(normalIndexes.z)]
            
            self.normals = (n0, n1, n2)
        } else {
            self.normals = nil
        }
        
        // Tangents
        if mesh.hasTangents {
            let tangentIndexes = mesh.faceTangentIndexes[faceId]
            let t0 = mesh.tangents[Int(tangentIndexes.x)]
            let t1 = mesh.tangents[Int(tangentIndexes.y)]
            let t2 = mesh.tangents[Int(tangentIndexes.z)]
            
            self.tangents = t0.length != 0 && t1.length != 0 && t2.length != 0
                ? (t0, t1, t2)
                : nil
        } else {
            self.tangents = nil
        }
        
        // UV Coordinates
        if mesh.hasUvs {
            let uvIndexes =  mesh.faceUvIndexes[faceId]
            let uv0 = mesh.uvs[Int(uvIndexes.x)]
            let uv1 = mesh.uvs[Int(uvIndexes.y)]
            let uv2 = mesh.uvs[Int(uvIndexes.z)]
            
            self.uvCoordinates = (uv0, uv1, uv2)
        } else {
            self.uvCoordinates = nil
        }
        
        // Area
        self.area = edge1.cross(edge2).length / 2
    }

    func hit(r: Ray) -> Intersection? {
        Scene.NB_INTERSECTION += 1
        
        let epsilon: Float = 0.0000001
        let (p0, p1, p2) = vertices
        
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

        let wo = -r.d
        let backface = wo.dot(n) < 0
        return Intersection(
            t: t,
            p: p,
            wi: (r.o - p).normalized(),
            n: backface ? -n : n,
            tan: .zero,
            bitan: .zero,
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
        
        let d = p - y
        let backface = d.dot(n) < 0
        let gn = backface ? -n : n
        return EmitterSample(y: y, n: gn, uv: uv(coordinates: (1 - u - v, u, v)), pdf: pdfDirect(shape: self, p: p, y: y, n: gn), shape: self)
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

//
//  mesh.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-01.
//

import Foundation
import SwiftWavefront

// TODO Caching
final class Mesh: Shape {
    unowned var material: Material!
    unowned var light: Light!

    private(set) var area: Float = 0
    private(set) var triangles: [Triangle] = []

    private var cdf: CDF

    init(filename: URL, transform: Transform) {
        let wavefront = Wavefront(filename: filename, encoding: .utf8)
        do {
            try wavefront.parse()
        } catch {
            print("Error while parsing mesh")
        }
        
        var facePositionIndexes: [Vec3] = []
        var faceNormalIndexes: [Vec3] = []
        var faceUvIndexes: [Vec3] = []

        let positions: [Point3] = stride(from: 0, through: wavefront.vertices.count - 1, by: 3).map { i in
            let x = wavefront.vertices[i]
            let y = wavefront.vertices[i + 1]
            let z = wavefront.vertices[i + 2]
            return transform.point(Vec3(x, y, z))
        }
        
        let normals: [Vec3] = stride(from: 0, through: wavefront.normals.count - 1, by: 3).map { i in
            let x = wavefront.normals[i]
            let y = wavefront.normals[i + 1]
            let z = wavefront.normals[i + 2]
            return transform.normal(Vec3(x, y, z)).normalized()
        }
        
        let uvs: [Vec2] = stride(from: 0, through: wavefront.textcoords.count - 1, by: 2).map { i in
            let u = wavefront.textcoords[i]
            let v = wavefront.textcoords[i + 1]
            return Vec2(u, v)
        }

        for s in wavefront.shapes {
            var offset = 0
            for nfv in s.numFaceVertices {
                var newIdxVertex: [Float] = []
                var newIdxNormal: [Float] = []
                var newIdxTexture: [Float] = []
                for v in 0 ..< nfv {
                    let idx = s.indices[offset + Int(v)]
                    newIdxVertex.append(Float(idx.vIndex))
                    
                    if idx.vnIndex >= 0 {
                        newIdxNormal.append(Float(idx.vnIndex))
                    }
                    
                    if idx.vtIndex >= 0 {
                        newIdxTexture.append(Float(idx.vtIndex))
                    }
                }
                
                facePositionIndexes.append(Vec3(newIdxVertex[0], newIdxVertex[1], newIdxVertex[2]))
                if !newIdxNormal.isEmpty {
                    faceNormalIndexes.append(Vec3(newIdxNormal[0], newIdxNormal[1], newIdxNormal[2]))
                }
                if !newIdxTexture.isEmpty {
                    faceUvIndexes.append(Vec3(newIdxTexture[0], newIdxTexture[1], newIdxTexture[2]))
                }
                offset += Int(nfv)
            }
        }

        self.cdf = CDF()
        // Build triangles
        for id in 0 ..< facePositionIndexes.count {
            let vIndexes = facePositionIndexes[id]
            let v = (
                positions[Int(vIndexes.x)],
                positions[Int(vIndexes.y)],
                positions[Int(vIndexes.z)]
            )
           
            let n: (Vec3, Vec3, Vec3)?
            if normals.isEmpty {
                n = nil
            } else {
                let nIndexes = faceNormalIndexes[id]
                n = (
                    normals[Int(nIndexes.x)],
                    normals[Int(nIndexes.y)],
                    normals[Int(nIndexes.z)]
                )
            }

            let uv: (Vec2, Vec2, Vec2)?
            if uvs.isEmpty {
                uv = nil
            } else {
                let uvIndexes = faceUvIndexes[id]
                uv = (
                    uvs[Int(uvIndexes.x)],
                    uvs[Int(uvIndexes.y)],
                    uvs[Int(uvIndexes.z)]
                )
            }

            
            let triangle = Triangle(mesh: self, vertices: v, normals: n, uvs: uv)
            triangles.append(triangle)
            let triangleArea = triangle.area
            area += triangleArea
            cdf.add(triangleArea)
        }

        cdf.build()
    
        print("Loaded: \(filename)")
    }
    
    func hit(r: Ray) -> Intersection? {
        return nil
    }
    
    func aabb() -> AABB {
        var result = AABB()
        for t in triangles {
            result = result.merge(with: t.aabb())
        }

        return result.sanitized()
    }
    
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample {
        var rng = sample
        let i = cdf.sample(s: sample.x)
        let n = Float(triangles.count)
        rng.x = sample.x * n - i
        let triangle = triangles[Int(i)]
        let triangleSample = triangle.sampleDirect(p: p, sample: rng)
        return EmitterSample(
            y: triangleSample.y,
            n: triangleSample.n,
            uv: triangleSample.uv,
            pdf: triangleSample.pdf * pdf(),
            shape: triangle
        )
    }
    
    func pdfDirect(shape: any Shape, p: Point3, y: Point3, n: Vec3) -> Float {
        return shape.pdfDirect(shape: shape, p: p, y: y, n: n) * pdf()
    }
    
    private func pdf() -> Float {
        return 1 / cdf.total
    }
}

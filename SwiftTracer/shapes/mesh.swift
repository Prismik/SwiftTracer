//
//  mesh.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-01.
//

import Foundation
import SwiftWavefront

// TODO Caching
final class Mesh {
    let name: String

    var material: Material!

    var hasNormals: Bool { return !normals.isEmpty }
    var hasUvs: Bool { return !uvs.isEmpty }
    var hasTangents: Bool { return !tangents.isEmpty }
    unowned var light: Light!

    private(set) var facePositionIndexes: [Vec3] = []
    private(set) var faceNormalIndexes: [Vec3] = []
    private(set) var faceUvIndexes: [Vec3] = []
    private(set) var faceTangentIndexes: [Vec3] = []

    private(set) var positions: [Point3] = []
    private(set) var normals: [Vec3] = []
    private(set) var uvs: [Vec2] = []
    private(set) var tangents: [Vec3] = []

    init(positions: [Vec3], normals: [Vec3]) {
        self.positions = positions
        self.tangents = []
        self.facePositionIndexes = [Vec3(0, 1, 2)]
        self.faceNormalIndexes = normals.isEmpty ? [] : [Vec3(0, 1, 2)]
        self.faceUvIndexes = []
        self.faceTangentIndexes = []
        self.normals = normals
        self.uvs = []
        self.name = ""
    }

    init(filename: URL, transform: Transform) {
        let wavefront = Wavefront(filename: filename, encoding: .utf8)
        self.name = filename.lastPathComponent
        do {
            try wavefront.parse()
        } catch {
            print("Error while parsing mesh")
        }

        self.positions = stride(from: 0, through: wavefront.vertices.count - 1, by: 3).map { i in
            let x = wavefront.vertices[i]
            let y = wavefront.vertices[i + 1]
            let z = wavefront.vertices[i + 2]
            return transform.point(Vec3(x, y, z))
        }
        
        self.normals = stride(from: 0, through: wavefront.normals.count - 1, by: 3).map { i in
            let x = wavefront.normals[i]
            let y = wavefront.normals[i + 1]
            let z = wavefront.normals[i + 2]
            return transform.normal(Vec3(x, y, z)).normalized()
        }
        
        self.uvs = stride(from: 0, through: wavefront.textcoords.count - 1, by: 2).map { i in
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

        print("Loaded: \(filename)")
    }
}

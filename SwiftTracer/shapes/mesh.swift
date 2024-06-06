//
//  mesh.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-01.
//

import Foundation

/// TODO Caching
final class Mesh {
    var material: Material!

    var hasNormals: Bool { return !normals.isEmpty }
    var hasUvs: Bool { return !uvs.isEmpty }
    var hasTangents: Bool { return !tangents.isEmpty }
    
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
    }

    init(filename: String, transform: Transform) {
        var reader = tinyobj.ObjReader()
        let config = tinyobj.ObjReaderConfig()
        reader.ParseFromFile(std.string(filename), config)
        let attributes = reader.attrib_
        let shapes = reader.shapes_

        self.positions = stride(from: 0, through: attributes.vertices.size() - 1, by: 3).map { i in
            let x = attributes.vertices[i]
            let y = attributes.vertices[i + 1]
            let z = attributes.vertices[i + 2]
            return transform.point(Vec3(x, y, z))
        }
        
        self.normals = stride(from: 0, through: attributes.normals.size() - 1, by: 3).map { i in
            let x = attributes.normals[i]
            let y = attributes.normals[i + 1]
            let z = attributes.normals[i + 2]
            return transform.normal(Vec3(x, y, z)).normalized()
        }
        
        self.uvs = stride(from: 0, through: attributes.texcoords.size() - 1, by: 2).map { i in
            let u = attributes.texcoords[i]
            let v = attributes.texcoords[i + 1]
            return Vec2(u, v)
        }

        for s in shapes {
            var offset = 0
            for nfv in s.mesh.num_face_vertices {
                var newIdxVertex: [Float] = []
                var newIdxNormal: [Float] = []
                var newIdxTexture: [Float] = []
                for v in 0 ..< nfv {
                    let idx = s.mesh.indices[offset + Int(v)]
                    newIdxVertex.append(Float(idx.vertex_index))
                    
                    if idx.normal_index >= 0 {
                        newIdxNormal.append(Float(idx.normal_index))
                    }
                    
                    if idx.texcoord_index >= 0 {
                        newIdxTexture.append(Float(idx.texcoord_index))
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

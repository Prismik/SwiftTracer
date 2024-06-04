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
    
    let facePositionIndexes: [Vec3]
    let faceNormalIndexes: [Vec3]
    let faceUvIndexes: [Vec3]
    let faceTangentIndexes: [Vec3]

    let positions: [Point3]
    let normals: [Vec3]
    let uvs: [Vec2]
    let tangents: [Vec3]

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
        tangents = []
        faceTangentIndexes = []
        
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
            return transform.normal(Vec3(x, y, z))
        }
        
        self.uvs = stride(from: 0, through: attributes.texcoords.size() - 1, by: 2).map { i in
            let u = attributes.texcoords[i]
            let v = attributes.texcoords[i + 1]
            return Vec2(u, v)
        }

        var facePositionIdx: [Vec3] = []
        var faceNormalIdx: [Vec3] = []
        var faceUvIdx: [Vec3] = []
        for s in shapes {
            let offset = facePositionIdx.count
            for face in stride(from: 0, through: s.mesh.indices.count - 1, by: 3) {
                let subset = s.mesh.indices[face ..< face + 3]
                let v = Vec3(
                    Float(subset[0 + face].vertex_index) + Float(offset),
                    Float(subset[1 + face].vertex_index) + Float(offset),
                    Float(subset[2 + face].vertex_index) + Float(offset)
                )
                facePositionIdx.append(v)
                let n = Vec3(
                    Float(subset[0 + face].normal_index) + Float(offset),
                    Float(subset[1 + face].normal_index) + Float(offset),
                    Float(subset[2 + face].normal_index) + Float(offset)
                )
                faceNormalIdx.append(n)
                let uv = Vec3(
                    Float(subset[0 + face].texcoord_index) + Float(offset),
                    Float(subset[1 + face].texcoord_index) + Float(offset),
                    Float(subset[2 + face].texcoord_index) + Float(offset)
                )
                faceUvIdx.append(uv)
            }
        }
        self.facePositionIndexes = facePositionIdx
        self.faceNormalIndexes = faceNormalIdx
        self.faceUvIndexes = faceUvIdx
        print("Loaded: \(filename)")
    }
}

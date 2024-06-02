//
//  mesh.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-01.
//

import Foundation

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

    init() {
        positions = []
        normals = []
        uvs = []
        tangents = []
        facePositionIndexes = []
        faceNormalIndexes = []
        faceUvIndexes = []
        faceTangentIndexes = []
    }
}

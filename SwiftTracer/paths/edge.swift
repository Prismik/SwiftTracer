//
//  edge.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

struct Edge {
    let start: Vertex
    let end: Vertex
    let d: Vec3
    let distance: Float

    init(start: Vertex, end: Vertex) {
        self.start = start
        self.end = end
        self.d = end.position - start.position
        self.distance = self.d.length
    }
}

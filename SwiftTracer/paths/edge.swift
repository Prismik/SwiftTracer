//
//  edge.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

struct Edge {
    let start: any Vertex
    let end: any Vertex
    let d: Vec3
    let distance: Float
    let weight: Color
    let contribution: Color

    init(start: any Vertex, end: any Vertex, weight: Color, contribution: Color = Color()) {
        self.start = start
        self.end = end
        let direction = (end.position - start.position)
        self.distance = direction.length
        self.d = direction.normalized()
        self.weight = weight
        self.contribution = contribution
    }
}

extension Edge: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.d == rhs.d && lhs.distance == rhs.distance && lhs.weight == rhs.weight && lhs.contribution == rhs.contribution
    }
}

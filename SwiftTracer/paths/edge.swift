//
//  edge.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

struct Edge {
    var start: any Vertex
    var end: any Vertex
    let d: Vec3
    let distance: Float
    var weight: Color
    let contribution: Color
    let connector: Bool

    private init(start: any Vertex, end: any Vertex, weight: Color, contribution: Color, connector: Bool) {
        self.start = start
        self.end = end
        let direction = (end.position - start.position)
        self.distance = direction.length
        self.d = direction.normalized()
        self.weight = weight
        self.contribution = contribution
        self.connector = connector
    }
    
    static func make(start: any Vertex, end: any Vertex, weight: Color, contribution: Color = Color()) -> Edge {
        var edge = Edge(start: start, end: end, weight: weight, contribution: contribution, connector: false)
        edge.start.outgoing = edge
        edge.end.incoming = edge
        return edge
    }
    
    /// Creates an edge and assign the weight based on the intersection of a ray from `start` to `end`.
    static func connector(start: any Vertex, end: any Vertex, contribution: Color = Color()) -> Edge {
        var edge = Edge(start: start, end: end, weight: .zero, contribution: contribution, connector: true)
        edge.start.outgoing = edge
        edge.end.incoming = edge
        edge.weight = edge.li()
        return edge
    }
    
    func li() -> Color {
        guard let intersection = end.intersection else { return .zero }
        guard let next = end.outgoing else { return .zero }

        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -d)
        let wi = frame.toLocal(v: next.d)
        let eval = intersection.shape.material.evaluate(wo: wo, wi: wi, uv: intersection.uv, p: intersection.p)
        let pdf = intersection.shape.material.pdf(wo: wo, wi: wi, uv: intersection.uv, p: intersection.p)
        let weight = eval / pdf
        guard weight.isFinite else { return .zero }

        return weight
    }
}

extension Edge: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.d == rhs.d && lhs.distance == rhs.distance && lhs.weight == rhs.weight && lhs.contribution == rhs.contribution
    }
}

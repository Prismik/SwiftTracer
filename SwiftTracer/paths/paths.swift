//
//  paths.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

final class Path {
    private(set) var edges: [Edge] = []
    private(set) var vertices: [Vertex] = []
    
    /// Constructs the root of a path starting at a given vertex
    static func start(at vertex: Vertex) -> Path {
        return Path(start: vertex)
    }

    private init() { }
    
    private init(start: Vertex) {
        vertices.append(start)
    }
    
    func add(vertex: Vertex) {
        guard let last = vertices.last else { return }
        let edge = Edge(start: last, end: vertex)
        vertices.append(vertex)
        edges.append(edge)
    }
}

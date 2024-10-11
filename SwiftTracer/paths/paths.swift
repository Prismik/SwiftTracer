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
    private init(edges: [Edge], vertices: [Vertex]) {
        self.edges = edges
        self.vertices = vertices
    }

    private init(start: Vertex) {
        vertices.append(start)
    }
    
    func add(vertex: Vertex) {
        guard let last = vertices.last else { return }
        let edge = Edge(start: last, end: vertex)
        vertices.append(vertex)
        edges.append(edge)
    }
    
    func connectable(with vertex: Vertex, at index: Int, within scene: Scene) -> Bool {
        let other = vertices[index + 1]
        
        if other.connectable && vertex.connectable {
            return vertex.position.visible(from: other.position, within: scene)
        }
        
        return false
    }
    
    /// Connects the prefix of `path` to `self`, starting at a given index.
    func connect(to path: Path, at index: Int) -> Path {
        let suffixVertices = vertices.suffix(vertices.count - index)
        let suffixEdges = edges.suffix(edges.count - index)
        guard let first = path.vertices.last, let second = vertices.first else { fatalError("Trying to connect an invalid path") }
        let connector = Edge(start: first, end: second)
        let vertices = path.vertices + suffixVertices
        let edges = path.edges + [connector] + suffixEdges
        return Path(edges: edges, vertices: vertices)
    }
}

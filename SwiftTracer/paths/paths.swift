//
//  paths.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

final class Path {
    private(set) var edges: [Edge] = []
    private(set) var vertices: [any Vertex] = []
    
    /// Constructs the root of a path starting at a given vertex
    static func start(at vertex: any Vertex) -> Path {
        return Path(start: vertex)
    }

    private init() { }
    private init(edges: [Edge], vertices: [any Vertex]) {
        self.edges = edges
        self.vertices = vertices
    }

    private init(start: any Vertex) {
        vertices.append(start)
    }
    
    func clear() {
        edges = []
        vertices = []
    }

    // TODO Figure out what to default weight to
    func add(vertex: any Vertex, weight: Color = Color(), contribution: Color = Color()) {
        guard let last = vertices.last else { return }
        let edge = Edge(start: last, end: vertex, weight: weight, contribution: contribution)
        vertices[vertices.count - 1].outgoing = edge
        vertices.append(vertex)
        vertices[vertices.count - 1].incoming = edge
        edges.append(edge)
    }
    
    func connectable(with vertex: any Vertex, at index: Int, within scene: Scene) -> Bool {
        let other = vertices[index + 1]
        
        if other.connectable && vertex.connectable {
            return vertex.position.visible(from: other.position, within: scene)
        }
        
        return false
    }
    
    /// Connects the prefix of `path` to the suffix of `self`, starting at a given index.
    func connect(to path: Path, at index: Int) -> Path {
        let suffixVertices = vertices.suffix(vertices.count - index)
        let suffixEdges = edges.suffix(edges.count - index)
        guard let first = path.vertices.last, let second = vertices.first else { fatalError("Trying to connect an invalid path") }
        // TODO Bring back the weight
        let connector = Edge(start: first, end: second, weight: Color())
        let vertices = path.vertices + suffixVertices
        let edges = path.edges + [connector] + suffixEdges
        return Path(edges: edges, vertices: vertices)
    }
    
    var contribution: Color {
        guard let start = vertices.first else { return Color() }
        return bounce(depth: 1)
    }
    
    private func bounce(depth: Int) -> Color {
        guard let edge = vertices[depth].incoming else { return Color() }
        return edge.contribution + bounce(depth: depth + 1) * edge.weight
    }
}

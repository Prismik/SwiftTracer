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
    
    func clear() {
        edges = []
        vertices = []
    }

    // TODO Figure out what to default weight to
    func add(vertex: Vertex, weight: Color = Color(), contribution: Color = Color()) {
        guard let last = vertices.last else { return }
        let edge = Edge(start: last, end: vertex, weight: weight, contribution: contribution)
        vertices[vertices.count - 1].outgoing = edge
        vertices.append(vertex)
        vertices[vertices.count - 1].incoming = edge
        edges.append(edge)
    }
    
    func connectable(with vertex: Vertex, within scene: Scene) -> Bool {
        guard let other = vertices.last else { return false }
        if other.connectable && vertex.connectable {
            return vertex.position.visible(from: other.position, within: scene)
        }
        
        return false
    }
    
    /// Connects the vertices of `self` to the suffix of `path`, start the suffix at a given 0-based index.
    func connect(to path: Path, at index: Int) -> Path {
        // TODO Possibly assert or guard against invalid indexes

        let suffixVertices = path.vertices.suffix(path.vertices.count - index)
        let suffixEdges = path.edges.suffix(path.edges.count - index)
        guard let first = vertices.last, let second = suffixVertices.first else { fatalError("Trying to connect an invalid path") }
        // TODO Bring back the weight
        let connector = Edge(start: first, end: second, weight: Color())
        let vertices = vertices + suffixVertices
        let edges = edges + [connector] + suffixEdges
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

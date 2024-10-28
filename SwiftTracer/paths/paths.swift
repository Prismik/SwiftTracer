//
//  paths.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

/// Path traversed by a ray of light.
/// > The edge-vertex recursive relationship ends at the first depth for now.
/// Do not use instances deeper than the 1st level.
final class Path {
    private(set) var edges: [Edge] = []
    private(set) var vertices: [Vertex] = []
    private(set) var pdf: Float = 1
    private(set) var jacobian: Float = 1

    /// Constructs the root of a path starting at a given vertex
    static func start(at vertex: Vertex) -> Path {
        return Path(start: vertex)
    }

    private init() { }
    private init(edges: [Edge], vertices: [Vertex]) {
        self.edges = edges
        self.vertices = vertices
        var pdf: Float = 1
        for edge in edges {
            pdf *= edge.pdf
            
        }
        self.pdf = pdf
    }

    private init(start: Vertex) {
        vertices.append(start)
    }
    
    func clear() {
        edges = []
        vertices = []
    }

    func accumulate(indirect contribution: Color, pdf: Float) {
        
    }

    func add(vertex: Vertex, weight: Color = .zero, contribution: Color, pdf: Float = 1) {
        guard let last = vertices.last else { return }
        
        // Setup edge
        let edge: Edge = .make(start: last, end: vertex, weight: weight, contribution: contribution, pdf: pdf)
        if edges.count > 0 { edges[edges.count - 1].end.outgoing = edge }
        edges.append(edge)
        
        // Setup vertices
        vertices[vertices.count - 1].outgoing = edge
        vertices.append(vertex)
        vertices[vertices.count - 1].incoming = edge
        
        self.pdf *= pdf
    }
    
    func terminate(outgoing: Vec3) {
        guard let last = vertices.last else { return }
        let edge: Edge = .make(start: last, end: NullVertex(position: last.position + outgoing), weight: .zero, contribution: .zero, pdf: 1)
        vertices[vertices.count-1].outgoing = edge
    }
    
    func connectable(with vertex: Vertex, within scene: Scene) -> Bool {
        guard let other = vertices.last else { return false }

        return other.connectable && vertex.connectable
    }
    
    /// Connects the vertices of `self` to the suffix of `path`, starting the suffix at a given vertex.
//    func connect(to path: Path, at index: Int, integrator: PathSpaceIntegrator, scene: Scene) -> Path? {
//        // TODO Possibly assert or guard against invalid indexes, especially (path.edges.count - index > 0)
//        let replacedEdge = path.edges[index - 1]
//        let suffixVertices = path.vertices.suffix(path.vertices.count - index)
//        let suffixEdges = path.edges.suffix(path.edges.count - index)
//        guard let first = vertices.last, let second = suffixVertices.first else { fatalError("Trying to connect an invalid path") }
//        guard first.position.visible(from: second.position, within: scene) else { return nil }
//
//        var connector: Edge = .connector(start: first, end: second, pdf: replacedEdge.pdf, scene: scene, replacedEdge: replacedEdge)
//        jacobian = computeJacobian(main: replacedEdge, shifted: connector)
//        
////        connector.pdf *= jacobian
////        connector.weight *= jacobian
////        connector.contribution *= jacobian
//
//        let vertices = vertices + suffixVertices
//        let edges = edges + [connector] + suffixEdges
//        return Path(edges: edges, vertices: vertices)
//    }
    
    var contribution: Color {
        guard !edges.isEmpty else { return Color() }

        let contrib = trace(depth: 0)
        return contrib * jacobian
    }

    private func trace(depth: Int) -> Color {
        let edge = edges[depth]
        guard depth < edges.count - 1 else { return edge.contribution }

        let acc = edge.contribution + trace(depth: depth + 1) * edge.weight
        return acc
    }
    
    private func computeJacobian(main: Edge, shifted: Edge) -> Float {
        guard let normal = main.end.intersection?.n else { return 0 }

        let mainCos = main.d.dot(normal)
        let shiftedCos = shifted.d.dot(normal)
        return abs(shiftedCos * main.distanceSquared) / (Float.leastNonzeroMagnitude + abs(mainCos * shifted.distanceSquared))
    }
}

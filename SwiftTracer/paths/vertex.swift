//
//  vertex.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

enum VertexType {
    case light
    case surface
    case camera
}

protocol Vertex: Equatable {
    var position: Point3 { get }
    var incoming: Edge? { get set }
    var outgoing: Edge? { get set }
    var connectable: Bool { get }

    func contribution(of edge: Edge) -> Color
    static func == (lhs: Self, rhs: Self) -> Bool
}

struct SurfaceVertex: Vertex {
    let type: VertexType = .surface
    var position: Point3 { intersection.p }
    var incoming: Edge?
    var outgoing: Edge?
    let intersection: Intersection
    
    func contribution(of edge: Edge) -> Color {
        return .zero
    }
    
    var connectable: Bool {
        !intersection.shape.material.hasDelta(uv: intersection.uv, p: position)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.type == rhs.type && lhs.position == rhs.position
    }
}

struct LightVertex: Vertex {
    let type: VertexType = .light
    // TODO Check that we want the point on the light source locally, or in world coordinates
    var position: Point3 { intersection.p }
    var incoming: Edge?
    var outgoing: Edge?
    // Similar to this, check that we want the normal on the light source locally, or in world coordinates
    var n: Vec3 { intersection.n }
    var uv: Vec2 { intersection.uv }
    /// Only type of light source we can intersect for now
    let intersection: Intersection
    
    var connectable: Bool { false }
    
    func contribution(of edge: Edge) -> Color {
        guard let light = intersection.shape.light else { fatalError("Inconsistent vertex with scene description") }
        return light.L(p: position, n: n, uv: uv, wo: -edge.d)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.type == rhs.type && lhs.position == rhs.position
    }
}

struct CameraVertex: Vertex {
    let type: VertexType = .camera
    let position: Point3 = .zero
    var incoming: Edge?
    var outgoing: Edge?
    var connectable: Bool { false }
    
    init() {
        self.incoming = nil
        self.outgoing = nil
    }
    
    func contribution(of edge: Edge) -> Color {
        return .zero
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.type == rhs.type && lhs.position == rhs.position
    }
}

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

protocol Vertex {
    var type: VertexType { get }
    var position: Point3 { get }
    var incoming: Edge? { get set }
    var outgoing: Edge? { get set }
    var connectable: Bool { get }
    var intersection: Intersection? { get }
    func contribution(of edge: Edge) -> Color
}

struct SurfaceVertex: Vertex {
    let type: VertexType = .surface
    var position: Point3 { intersection?.p ?? .zero }
    // TODO Allow for several incoming edges in the case of shadow rays
    var incoming: Edge?
    var outgoing: Edge?
    let intersection: Intersection?
    
    func contribution(of edge: Edge) -> Color {
        return .zero
    }
    
    var connectable: Bool {
        guard let its = intersection else { return false }
        return !its.shape.material.hasDelta(uv: its.uv, p: position)
    }
}

struct LightVertex: Vertex {
    let type: VertexType = .light
    // TODO Check that we want the point on the light source locally, or in world coordinates
    var position: Point3 { intersection?.p ?? .zero }
    var incoming: Edge?
    var outgoing: Edge?
    // Similar to this, check that we want the normal on the light source locally, or in world coordinates
    var n: Vec3 { intersection?.n ?? .zero }
    var uv: Vec2 { intersection?.uv ?? .zero }
    
    var connectable: Bool { false }
    let intersection: Intersection?
    
    func contribution(of edge: Edge) -> Color {
        guard let light = intersection?.shape.light else { fatalError("Inconsistent vertex with scene description") }
        return light.L(p: position, n: n, uv: uv, wo: -edge.d)
    }
}

struct CameraVertex: Vertex {
    let type: VertexType = .camera
    let position: Point3
    var incoming: Edge?
    var outgoing: Edge?
    var connectable: Bool { false }
    var intersection: Intersection? { nil }
    init(camera: Camera) {
        self.position = camera.transform.point(.zero)
        self.incoming = nil
        self.outgoing = nil
    }
    
    /// This initalializer yields incorrect results while rendering.
    init() {
        self.position = .zero
    }
    
    func contribution(of edge: Edge) -> Color {
        return .zero
    }
}

//
//  vertex.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

protocol Vertex {
    var position: Point3 { get }
    var incoming: [Edge] { get }
    var outgoing: [Edge] { get }
}

struct SurfaceVertex: Vertex {
    var position: Point3 { return intersection.p }
    let incoming: [Edge]
    let outgoing: [Edge]
    let intersection: Intersection
}

struct LightVertex: Vertex {
    // TODO Check that we want the point on the light source locally, or in world coordinates
    let position: Point3
    let incoming: [Edge]
    let outgoing: [Edge]
    // Similar to this, check that we want the normal on the light source locally, or in world coordinates
    let n: Vec3
    /// Only type of light source we can intersect for now
    let light: AreaLight
}

struct CameraVertex: Vertex {
    let position: Point3 = .zero
    let incoming: [Edge]
    let outgoing: [Edge]
    
    init() {
        self.incoming = []
        self.outgoing = []
    }
}

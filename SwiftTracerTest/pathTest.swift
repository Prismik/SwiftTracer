//
//  pathTest.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-12.
//

import XCTest

#if os(Linux)
@testable import SwiftTracer
#endif

final class PathTest: XCTestCase {
    var path: Path!
    override func setUpWithError() throws {
        path = .start(at: CameraVertex())
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        path.clear()
    }

    func intersection(p: Point3) -> Intersection {
        return Intersection(t: 10, p: p, n: Vec3(), tan: Vec3(), bitan: Vec3(), uv: Vec2(), shape: Quad(halfSize: Vec2(50, 50), transform: Transform(m: Mat4())))
    }
    
    func testAddSurfaceVertex() {
        XCTAssertEqual(path.edges.count, 0)
        XCTAssertEqual(path.vertices.count, 1)
        
        let shape = Quad(halfSize: Vec2(50, 50), transform: Transform(m: Mat4()))
        let p0 = Point3(0, 0, 0)
        let p1 = Point3(5, 5, 5)
        let v1 = p1 - p0
        let its = Intersection(t: v1.length, p: p1, n: Vec3(), tan: Vec3(), bitan: Vec3(), uv: Vec2(), shape: shape)
        let newVertex = SurfaceVertex(intersection: its)
        path.add(vertex: newVertex)
        
        XCTAssertEqual(path.edges.count, 1)
        XCTAssertEqual(path.vertices.count, 2)
        XCTAssertEqual(path.edges[0], path.vertices[0].outgoing)
        XCTAssertEqual(path.edges[0], path.vertices[1].incoming)
        
        let edge = path.edges[0]
        XCTAssertEqual(edge.d, v1.normalized())
    }
    
    func testConnectPaths() {
        // Camera vertex
        path.add(vertex: SurfaceVertex(intersection: intersection(p: Point3(2, 2, 8))))
        path.add(vertex: SurfaceVertex(intersection: intersection(p: Point3(5, 5, 5))))
        path.add(vertex: SurfaceVertex(intersection: intersection(p: Point3(11, 11, 5))))
        path.add(vertex: SurfaceVertex(intersection: intersection(p: Point3(15, 15, 9))))
        path.add(vertex: LightVertex(intersection: intersection(p: Point3(18, 18, 5))))
        
        let second: Path = .start(at: CameraVertex())
        second.add(vertex: SurfaceVertex(intersection: intersection(p: Point3(3, 3, 9))))
        second.add(vertex: SurfaceVertex(intersection: intersection(p: Point3(6, 6, 5))))
        second.add(vertex: SurfaceVertex(intersection: intersection(p: Point3(12, 12, 5))))
        
        let result = second.connect(to: path, at: second.vertices.count)
        
        // Look for position equality among vertices
        XCTAssertEqual(
            path.vertices.suffix(2).map { $0.position },
            result.vertices.suffix(2).map { $0.position }
        )
        
        XCTAssertEqual(
            second.vertices.prefix(4).map { $0.position },
            result.vertices.prefix(4).map { $0.position }
        )
        
        // Look for expected modified edge
        let edge = result.edges[3]
        XCTAssertEqual(edge.start.position, second.vertices[3].position)
        XCTAssertEqual(edge.end.position, path.vertices[4].position)
    }
    
    func testContribution() {
        path.add(
            vertex: SurfaceVertex(intersection: intersection(p: Point3(3, 3, 9))), 
            weight: Color(1, 0.5, 0.5),
            contribution: Color(0.5, 0.5, 0.5)
        )

        path.add(
            vertex: SurfaceVertex(intersection: intersection(p: Point3(6, 6, 6))),
            weight: Color(0.5, 1, 0.5),
            contribution: Color(0.5, 0.5, 0.5)
        )
        
        path.add(
            vertex: SurfaceVertex(intersection: intersection(p: Point3(6, 6, 9))),
            weight: Color(0.5, 0.5, 1),
            contribution: Color(0.5, 0.5, 0.5)
        )

        path.add(
            vertex: LightVertex(intersection: intersection(p: Point3(12, 12, 6))),
            weight: Color(0, 0, 0),
            contribution: Color(1, 1, 1)
        )

        let expected = Color(1.5, 1.25, 1.125)
        XCTAssertEqual(path.contribution, expected)
    }
}
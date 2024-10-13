//
//  pathTest.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-12.
//

import XCTest

final class PathTest: XCTestCase {
    var path: Path!
    override func setUpWithError() throws {
        path = .start(at: CameraVertex())
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
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
        XCTAssertEqual(edge.d, v1)
    }
    
    func testConnectPaths() {
        
    }
    
    func testContribution() {
        
    }
}

//
//  mathTest.swift
//  SwiftTracerTest
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import XCTest
import simd

#if os(Linux)
@testable import SwiftTracer
#endif

final class MathTest: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testElementwise() {
        let v1 = Vec3(5, 6, 7)
        let v2 = Vec3(5, 6, 7)
        
        XCTAssertEqual(v1 / v2, Vec3(1, 1, 1))
        XCTAssertEqual(v1 * v2, Vec3(5*5, 6*6, 7*7))
        XCTAssertEqual(v1 + v2, Vec3(5+5, 6+6, 7+7))
        XCTAssertEqual(v1 - v2, Vec3(0, 0, 0))
    }
    
    func testSign() {
        let negSign = sign(-999.987125125)
        let posSign = sign(0.000000000000000001)
        let nullSign = sign(0.0)
        XCTAssertEqual(Float(negSign), Float(-1))
        XCTAssertEqual(Float(posSign), Float(1))
        XCTAssertEqual(Float(nullSign), Float(0))
    }
}

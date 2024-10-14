//
//  array2dTest.swift
//  SwiftTracerTest
//
//  Created by Francis Beauchamp on 2024-05-25.
//

import XCTest
@testable import SwiftTracer

final class Array2dTest: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
 
    func testFlipVertically() throws {
        let a = Array2d(x: 3, y: 3, value: 5)
        a[0, 0] = 0
        a[0, 2] = 2
        
        let expected = Array2d(x: 3, y: 3, value: 5)
        expected[0, 0] = 2
        expected[0, 2] = 0
        
        a.flipVertically()
        
        XCTAssertEqual(a[0, 0], expected[0, 0])
        XCTAssertEqual(a[2, 2], expected[2, 2])
        XCTAssertEqual(a[0, 2], expected[0, 2])
        XCTAssertEqual(a[2, 0], expected[0, 2])
    }
}

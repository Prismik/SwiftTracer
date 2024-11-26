//
//  array2dTest.swift
//  SwiftTracerTest
//
//  Created by Francis Beauchamp on 2024-05-25.
//

import XCTest

#if os(Linux)
@testable import SwiftTracer
#endif

final class Array2dTest: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
 
    func testFlipVertically() throws {
        let a = Array2d(width: 3, height: 3, value: 5)
        a[0, 0] = 0
        a[0, 2] = 2
        
        let expected = Array2d(width: 3, height: 3, value: 5)
        expected[0, 0] = 2
        expected[0, 2] = 0
        
        a.flipVertically()
        
        XCTAssertEqual(a[0, 0], expected[0, 0])
        XCTAssertEqual(a[2, 2], expected[2, 2])
        XCTAssertEqual(a[0, 2], expected[0, 2])
        XCTAssertEqual(a[2, 0], expected[2, 2])
    }
    
    func testFlipVerticallyPixelBuffer() throws {
        let a = PixelBuffer(width: 3, height: 3, value: Color(repeating: 5))
        a[0, 0] = .zero
        a[0, 2] = Color(repeating: 2)
        
        let expected = PixelBuffer(width: 3, height: 3, value: Color(repeating: 5))
        expected[0, 0] = Color(repeating: 2)
        expected[0, 2] = .zero
        
        a.flipVertically()
        
        XCTAssertEqual(a[0, 0], expected[0, 0])
        XCTAssertEqual(a[2, 2], expected[2, 2])
        XCTAssertEqual(a[0, 2], expected[0, 2])
        XCTAssertEqual(a[2, 0], expected[2, 2])
    }
    
    func testIterateOnPixelBuffer() throws {
        let pixels: [Float] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
        let a = PixelBuffer(width: 3, height: 3, storage: pixels)
        
        let result = a.map { $0.x + $0.y + $0.z }.reduce(0, +)
        let expected =  pixels.reduce(0, +)
        XCTAssertEqual(result, expected)
    }
    
    func testOperatorOverloadsPixeBuffer() throws {
        let unit = Color(repeating: 1)
        let a = PixelBuffer(width: 3, height: 3, value: Color(repeating: 0))
        a[0, 0] += unit
        
        a[1, 1] += unit
        a[1, 1] += unit
        
        a[2, 2] += unit
        a[2, 2] += unit
        a[2, 2] += unit
        
        XCTAssertEqual(a[0, 0], unit)
        XCTAssertEqual(a[1, 1], unit * 2)
        XCTAssertEqual(a[2, 2], unit * 3)
    }
    
    func testAddingUpdatesTotal() throws {
        let unit = Color(repeating: 1)
        let a = PixelBuffer(width: 3, height: 3, value: Color(repeating: 0))
        XCTAssertEqual(a.total, .zero)
        
        a[0, 0] += unit
        XCTAssertEqual(a.total, unit)
    }
    
    func testScalingUpdatesTotal() throws {
        let factor: Float = 3
        let expected = Color(repeating: 9)
        let a = PixelBuffer(width: 3, height: 3, value: Color(repeating: 1))
        XCTAssertEqual(a.total, expected)
        
        a.scale(by: factor)
        XCTAssertEqual(a.total, expected * factor)
    }
    
    func testMergingUpdatesTotal() throws {
        let colorA = Color(repeating: 2)
        let a = PixelBuffer(width: 3, height: 3, value: Color(repeating: 2))
        XCTAssertEqual(a.total, colorA * 9)
        let colorB = Color(repeating: 3)
        let b = PixelBuffer(width: 3, height: 3, value: Color(repeating: 3))
        XCTAssertEqual(b.total, colorB * 9)
        
        a.merge(with: b)
        XCTAssertEqual(a.total, (colorA + colorB) * 9)
    }

    func testArrayVersusBuffer() throws {
        let a = Array2d(width: 1000, height: 1000, value: Color(repeating: 5))
        let b = PixelBuffer(width: 1000, height: 1000, value: Color(repeating: 5))
        
        let clock = ContinuousClock()
        let startA = clock.now
        a.scale(by: 1 / 5)
        let durationA = clock.now - startA
        
        let startB = clock.now
        b.scale(by: 1 / 5)
        let durationB = clock.now - startB
        
        print("Array2d => \(durationA)")
        print("PixelBuffer => \(durationB)")
        
        XCTAssertEqual(a[0, 0], Color(1, 1, 1))
        XCTAssertEqual(b[0, 0], Color(1, 1, 1))
    }
    
    
    func testBufferMerge() throws {
        let a = PixelBuffer(width: 1000, height: 1000, value: Color(repeating: 5))
        let b = PixelBuffer(width: 1000, height: 1000, value: Color(repeating: 5))
        
        a.merge(with: b)
        
        XCTAssertEqual(a[0, 0], Color(10, 10, 10))
    }
    
    func testBufferCreateEmpty() throws {
        let clock = ContinuousClock()
        let startA = clock.now
        let _ = Array2d(width: 1000, height: 1000, value: Color())
        let durationA = clock.now - startA
        
        let startB = clock.now
        let _ = PixelBuffer(width: 1000, height: 1000, value: Color())
        let durationB = clock.now - startB
        
        print("Array2d => \(durationA)")
        print("PixelBuffer => \(durationB)")
    }
}

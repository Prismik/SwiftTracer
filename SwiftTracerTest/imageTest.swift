//
//  imageTest.swift
//  SwiftTracerTest
//
//  Created by Francis Beauchamp on 2024-05-28.
//

import XCTest

final class ImageTest: XCTestCase {
    func testSimpleGenerate() {
        let length = 32
        let array = Array2d(x: length, y: length, value: Color(repeating: 1))
        let colors: [Color] = [Color(1, 1, 1), Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]

        for i in 0 ..< length {
            for j in 0 ..< length {
                let color: Color
                if i < length / 2 && j < length / 2 {
                    color = colors[0]
                } else if i >= length / 2 && j < length / 2 {
                    color = colors[1]
                } else if i < length / 2 && j >= length / 2 {
                    color = colors[2]
                } else {
                    color = colors[3]
                }
                
                array.set(value: color, i, j)
            }
        }
        let image = Image(array: array)
        let success = image.save(to: "xctest.png")
        XCTAssertEqual(success, true)
    }
}

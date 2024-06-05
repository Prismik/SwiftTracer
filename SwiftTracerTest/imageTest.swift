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
        let success = image.write(to: "xctest.png")
        XCTAssertEqual(success, true)
    }
    
    func testSimpleLoad() throws {
        let bundle = Bundle(for: type(of: self))
        let image = Image(filename: "xctest", bundle: bundle, subdir: nil)
        let unwrapped = try XCTUnwrap(image)
        
        let data = unwrapped.read()
        let rgb00 = data.get(0, 0)
        let rgb10 = data.get(data.xSize - 1, 0)
        let rgb01 = data.get(0, data.ySize - 1)
        let rgb11 = data.get(data.xSize - 1, data.ySize - 1)
        XCTAssertEqual(rgb00, Color(1, 1, 1))
        XCTAssertEqual(rgb10, Color(1, 0, 0))
        XCTAssertEqual(rgb01, Color(0, 1, 0))
        XCTAssertEqual(rgb11, Color(0, 0, 1))
    }
}

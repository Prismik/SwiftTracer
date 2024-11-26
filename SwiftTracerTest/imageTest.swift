//
//  imageTest.swift
//  SwiftTracerTest
//
//  Created by Francis Beauchamp on 2024-05-28.
//

import XCTest

#if os(Linux)
@testable import SwiftTracer
#endif

final class ImageTest: XCTestCase {
    var sample: PixelBuffer {
        let length = 32
        let array = PixelBuffer(width: length, height: length, value: Color(repeating: 1))
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
                
                array[i, j] = color
            }
        }
        
        return array
    }
    
    func testSimpleGenerate() {
        let success = Image(encoding: .png).write(img: sample, to: "xctest.png")
        XCTAssertEqual(success, true)
    }
    
    // TODO Rework
    func testSimpleLoad() throws {
        let image = Image(encoding: .png).read(file: URL(filePath: "xctest.png")!)
        let unwrapped = try XCTUnwrap(image)
        
        let data = unwrapped
        let rgb00 = data[0, 0]
        let rgb10 = data[data.width - 1, 0]
        let rgb01 = data[0, data.height - 1]
        let rgb11 = data[data.width - 1, data.height - 1]
        XCTAssertEqual(rgb00, Color(1, 1, 1))
        XCTAssertEqual(rgb10, Color(1, 0, 0))
        XCTAssertEqual(rgb01, Color(0, 1, 0))
        XCTAssertEqual(rgb11, Color(0, 0, 1))
    }
    
    func testPfmWrite() {
        let url = URL.documentsDirectory
        let result = PFM().write(img: sample, to: url.appending(path: "test.pfm"))
        XCTAssertTrue(result)
    }
}

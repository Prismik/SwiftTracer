//
//  pfm.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-11-07.
//

import Foundation

struct PFM: ImageEncoding {
    // TODO add a pfm reader
    func read(file: URL) -> PixelBuffer? {
        let result = PixelBuffer()
        return result
    }
    
    func write(img: PixelBuffer, to destination: URL) -> Bool {
        img.flipVertically()
        var data = Data()
        for var pixel in img {
            withUnsafePointer(to: &pixel.x) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
            withUnsafePointer(to: &pixel.y) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
            withUnsafePointer(to: &pixel.z) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
        }

        guard FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: nil) else { return false }
        guard let handle = FileHandle(forWritingAtPath: destination.path) else { return false }
        guard let line1 = "PF\n".data(using: .utf8) else { return false }
        guard let line2 = "\(img.width) \(img.height)\n".data(using: .utf8) else { return false }
        guard let line3 = "-1.0\n".data(using: .utf8) else { return false }
        
        do {
            try handle.write(contentsOf: line1)
            try handle.write(contentsOf: line2)
            try handle.write(contentsOf: line3)
            try handle.write(contentsOf: data)
            return true
        } catch {
            return false
        }
    }
}

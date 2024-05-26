//
//  image.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-26.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

class Image {
    private let raw: Array2d<Color>
    private let pixels : UnsafeMutableRawPointer
    private let context: CGContext
    init(array: Array2d<Color>) {
        self.raw = array
        let bytesPerRow = raw.xSize * MemoryLayout<Color>.size
        let size = raw.ySize * bytesPerRow
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)

        self.pixels = malloc(size)
        self.context = CGContext(
            data: pixels,
            width: array.xSize,
            height: array.ySize,
            bitsPerComponent: 16,
            bytesPerRow: bytesPerRow,
            space: colorSpace!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
    }
    
    func save(to filename: String) -> Bool {
        for (i, pixel) in raw.enumerated() {
            let offset = i * MemoryLayout<Color>.size
            pixels.storeBytes(of: pixel, toByteOffset: offset, as: Color.self)
        }

        guard let url = URL(string: "file:///Users/fbp/code/\(filename)") else { return false }
        guard let img = context.makeImage() else { return false }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
                
        CGImageDestinationAddImage(destination, img, nil)
        return CGImageDestinationFinalize(destination)
    }
}

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
    private struct BitmapPixel {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let u: UInt8 // For 32 bits alignment
        
        init(r: UInt8, g: UInt8, b: UInt8) {
            self.r = r
            self.g = g
            self.b = b
            self.u = 0
        }

        init(from: Color) {
            let r = max(0, min(from.x, 1))
            let g = max(0, min(from.y, 1))
            let b = max(0, min(from.z, 1))
            self.init(
                r: UInt8(r * 255),
                g: UInt8(g * 255),
                b: UInt8(b * 255)
            )
        }
    }

    private let raw: Array2d<Color>
    private let pixels : UnsafeMutableRawPointer
    private let context: CGContext
    init(array: Array2d<Color>) {
        self.raw = array
        let bytesPerRow = raw.xSize * MemoryLayout<BitmapPixel>.size
        let size = raw.ySize * bytesPerRow
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        
        self.pixels = malloc(size)
        self.context = CGContext(
            data: pixels,
            width: array.xSize,
            height: array.ySize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
    }
    
    deinit {
        free(pixels)
    }

    func save(to filename: String) -> Bool {
        for (i, pixel) in raw.enumerated() {
            let offset = i * MemoryLayout<BitmapPixel>.size
            pixels.storeBytes(of: BitmapPixel(from: pixel), toByteOffset: offset, as: BitmapPixel.self)
        }

        guard let url = URL(string: "file:///Users/fbp/code/\(filename)") else { return false }
        guard let img = context.makeImage() else { return false }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
                
        CGImageDestinationAddImage(destination, img, nil)
        return CGImageDestinationFinalize(destination)
    }
}

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

/// Based on "SwiftRay" by Renaud Pradenc
/// https://github.com/Ceroce/SwiftRay/blob/master/SwiftRay/SwiftRay/Bitmap.swift
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
    private let pixels : UnsafeMutableRawPointer!
    private let context: CGContext!
    private let cgImage: CGImage!

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
        self.cgImage = nil
    }
    
    init?(filename: String, bundle: Bundle = Bundle.main, subdir: String? = "assets") {
        guard let url = bundle.url(forResource: filename, withExtension: "png", subdirectory: subdir) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let size = cgImage.height * cgImage.bytesPerRow
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        self.raw = Array2d(x: cgImage.width, y: cgImage.height, value: Color())
        self.pixels = malloc(size)
        self.context = CGContext(
            data: pixels,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: cgImage.bytesPerRow,
            space: colorSpace!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        self.cgImage = cgImage
    }
    
    deinit {
        free(pixels)
    }

    func read() -> Array2d<Color> {
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: context.width, height: context.height), byTiling: false)
        let mem = pixels.assumingMemoryBound(to: UInt8.self)
        for x in 0 ..< context.width {
            for y in 0 ..< context.height {
                let i = context.bytesPerRow * y + MemoryLayout<BitmapPixel>.size * x
                let r = mem[i] / 255
                let g = mem[i + 1] / 255
                let b = mem[i + 2] / 255
                raw.set(value: Color(Float(r), Float(g), Float(b)), x, y)
            }
        }
        
        return raw
    }

    func write(to filename: String) -> Bool {
        for (i, pixel) in raw.enumerated() {
            let offset = i * MemoryLayout<BitmapPixel>.size
            pixels.storeBytes(of: BitmapPixel(from: pixel), toByteOffset: offset, as: BitmapPixel.self)
        }

        // TODO Better url handling at a given folder
        guard let url = URL(string: "file:///Users/fbp/code/\(filename)") else { return false }
        guard let img = context.makeImage() else { return false }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
                
        CGImageDestinationAddImage(destination, img, nil)
        return CGImageDestinationFinalize(destination)
    }
}

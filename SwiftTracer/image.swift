//
//  image.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-26.
//

import Foundation

#if os(Linux)
import PNG

class Image {
    private var path: String = ""
    private var pixels: Array2d<Color>
    init(array: Array2d<Color>) {
        self.pixels = array
    }

    init?(filename: String, bundle: Bundle = Bundle.main, subdir: String? = "assets") {
        guard let url = bundle.url(forResource: filename, withExtension: nil, subdirectory: subdir) else { return nil }
        self.path = url.absoluteString
        self.pixels = Array2d<Color>()
    }

    func read() -> Array2d<Color> {
        do {
            guard let image:PNG.Image = try .decompress(path: path) else {
                return pixels
            }

            let rgba: [PNG.RGBA<UInt8>] = image.unpack(as: PNG.RGBA<UInt8>.self)
            let size: (x:Int, y:Int) = image.size

            for x in 0 ..< size.x {
                for y in 0 ..< size.y {
                    let i = x + y * x
                    let v = rgba[i]
                    let r = Float(v.r) / 255
                    let g = Float(v.g) / 255
                    let b = Float(v.b) / 255
                    pixels.set(value: Color(r, g, b), x, y)
                }
            }
        } catch {
            return pixels
        }

        return pixels
    }

    func write(to filename: String) -> Bool {
        let packed = pixels.reduce(into: [PNG.RGBA<UInt8>](), { acc, rgb in
            acc.append(
                PNG.RGBA<UInt8>(
                    UInt8(rgb.x * 255), 
                    UInt8(rgb.y * 255), 
                    UInt8(rgb.z * 255)
                )
            )
        })
        let size = (pixels.xSize, pixels.ySize)
        let image: PNG.Image = .init(
            packing: packed, 
            size: size,
            layout: .init(format: .rgba8(palette: [], fill: nil))
        )
        do {
            try image.compress(path: path, level: 0)
            return true
        } catch {
            return false
        }
    }
}
#else
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Encapsulates raw image information using `CoreGraphics`.
///
/// Based on [SwiftRay](https://github.com/Ceroce/SwiftRay/blob/master/SwiftRay/SwiftRay/Bitmap.swift) by Renaud Pradenc.
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
        guard let url = bundle.url(forResource: filename, withExtension: nil, subdirectory: subdir) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let size = cgImage.height * cgImage.width * 4
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        self.raw = Array2d(x: cgImage.width, y: cgImage.height, value: Color())
        self.pixels = malloc(size)
        self.context = CGContext(
            data: pixels,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * cgImage.width,
            space: colorSpace!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        self.cgImage = cgImage
    }
    
    deinit {
        free(pixels)
    }

    /// Reads the bytes of the associated file found at the path `filename` given in the initializer. The content will be returned as an `Array2d` where values between 0 and 1.
    /// > Note: The pixel values are converted from standard RGB to linear RGB.
    func read() -> Array2d<Color> {
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: context.width, height: context.height), byTiling: false)
        let mem = pixels.assumingMemoryBound(to: UInt8.self)
        for x in 0 ..< context.width {
            for y in 0 ..< context.height {
                let i = context.bytesPerRow * y + MemoryLayout<BitmapPixel>.size * x
                let r = Float(mem[i]) / 255
                let g = Float(mem[i + 1]) / 255
                let b = Float(mem[i + 2]) / 255
                raw.set(value: Color(r, g, b).toLinearRGB(), x, y)
            }
        }
        
        return raw
    }

    /// Attempts to write the pixel values (RGB) into a new png file at the path `filename`.
    ///
    /// > Note: The pixel values are converted from linear RGB to [standard RGB](https://en.wikipedia.org/wiki/SRGB).
    func write(to filename: String) -> Bool {
        for (i, pixel) in raw.enumerated() {
            let offset = i * MemoryLayout<BitmapPixel>.size
            pixels.storeBytes(of: BitmapPixel(from: pixel.toSRGB()), toByteOffset: offset, as: BitmapPixel.self)
        }

        // TODO Better url handling at a given folder
        guard let url = URL(string: "file:///Users/fbp/code/\(filename)") else { return false }
        guard let img = context.makeImage() else { return false }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
                
        CGImageDestinationAddImage(destination, img, nil)
        return CGImageDestinationFinalize(destination)
    }
}
#endif

private extension Color {
    func toSRGB() -> Self {
        var result = Color()
        for i in 0 ..< 3 {
            let val = self[i]
            result[i] = val <= 0.0031308
                ? 12.92 * val
                : (1 + 0.055) * val.pow(1 / 2.4) - 0.055
        }
        
        return result
    }
    
    func toLinearRGB() -> Self {
        var result = Color()
        for i in 0 ..< 3 {
            let val = self[i]
            result[i] = val <= 0.04045
                ? val * (1 / 12.92)
                : ((val + 0.055) / 1.055).pow(2.4)
        }
        
        return result
    }
}

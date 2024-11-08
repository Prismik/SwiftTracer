//
//  png.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-11-07.
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

    init(filename: String) {
        let url = URL(fileURLWithPath: "SwiftTracer/assets/scenes/\(filename)")
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
            self.pixels = Array2d<Color>(x: size.x, y: size.x, value: .zero)
            for x in 0 ..< size.x {
                for y in 0 ..< size.y {
                    let i = x + y * size.x
                    let v = rgba[i]
                    let r = Float(v.r) / 255
                    let g = Float(v.g) / 255
                    let b = Float(v.b) / 255
                    pixels[x, y] = Color(r, g, b).toLinearRGB()
                }
            }
        } catch {
            return pixels
        }

        return pixels
    }

    func write(to filename: String) -> Bool {
        self.path = filename
        let packed = pixels.reduce(into: [PNG.RGBA<UInt8>](), { acc, rgb in
            let srgb = rgb.toSRGB()
            acc.append(
                PNG.RGBA<UInt8>(
                    UInt8(Int(max(0, min(srgb.x, 1)) * 255)),
                    UInt8(Int(max(0, min(srgb.y, 1)) * 255)),
                    UInt8(Int(max(0, min(srgb.z, 1)) * 255))
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
            return try image.compress(path: path, level: 0) != nil
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
struct PNG: ImageEncoding {
    func read(file: URL) -> Array2d<Color>? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard var cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let size = cgImage.height * cgImage.width * 4
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        let raw = Array2d<Color>(x: cgImage.width, y: cgImage.height, value: .zero)
        guard let pixels = malloc(size) else { return nil }
        guard let context = CGContext(
            data: pixels,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * cgImage.width,
            space: colorSpace!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: context.width, height: context.height), byTiling: false)
        let mem = pixels.assumingMemoryBound(to: UInt8.self)
        for x in 0 ..< context.width {
            for y in 0 ..< context.height {
                let i = context.bytesPerRow * y + MemoryLayout<BitmapPixel>.size * x
                let r = Float(mem[i]) / 255
                let g = Float(mem[i + 1]) / 255
                let b = Float(mem[i + 2]) / 255
                raw[x, y] = Color(r, g, b).toLinearRGB()
            }
        }
        
        free(pixels)
        return raw
    }

    func write(img: Array2d<Color>, to destination: URL) -> Bool {
        let bytesPerRow = img.xSize * MemoryLayout<BitmapPixel>.size
        let size = img.ySize * bytesPerRow
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        
        guard let pixels = malloc(size) else { return false }
        guard let context = CGContext(
            data: pixels,
            width: img.xSize,
            height: img.ySize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return false }

        for (i, pixel) in img.enumerated() {
            let offset = i * MemoryLayout<BitmapPixel>.size
            pixels.storeBytes(of: BitmapPixel(from: pixel.toSRGB()), toByteOffset: offset, as: BitmapPixel.self)
        }

        // TODO Better url handling at a given folder
        guard let url = URL(string: "file://\(destination.absoluteString)") else { return false }

        guard let img = context.makeImage() else { return false }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
                
        CGImageDestinationAddImage(destination, img, nil)
        return CGImageDestinationFinalize(destination)
    }
}

#endif

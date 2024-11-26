//
//  jpg.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-11-07.
//


import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Encapsulates raw image information using `CoreGraphics`.
///
/// Based on [SwiftRay](https://github.com/Ceroce/SwiftRay/blob/master/SwiftRay/SwiftRay/Bitmap.swift) by Renaud Pradenc.
struct JPG: ImageEncoding {
    func read(file: URL) -> PixelBuffer? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let size = cgImage.height * cgImage.width * 4
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        let raw = PixelBuffer(width: cgImage.width, height: cgImage.height, value: .zero)
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

    func write(img: PixelBuffer, to destination: URL) -> Bool {
        let bytesPerRow = img.width * MemoryLayout<BitmapPixel>.size
        let size = img.height * bytesPerRow
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        
        guard let pixels = malloc(size) else { return false }
        guard let context = CGContext(
            data: pixels,
            width: img.width,
            height: img.height,
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
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
                
        CGImageDestinationAddImage(destination, img, nil)
        return CGImageDestinationFinalize(destination)
    }
}

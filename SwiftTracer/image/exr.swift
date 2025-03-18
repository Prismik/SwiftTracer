//
//  exr.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-11-08.
//

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ModelIO

struct EXR: ImageEncoding {
    func read(file: URL) -> PixelBuffer? {
        guard let texture = MDLTexture(named: file.absoluteString) else { return nil }
        guard let image = texture.imageFromTexture()?.takeUnretainedValue() else { return nil }
        
        let size = image.height * image.width * 4
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        let raw = PixelBuffer(width: image.width, height: image.height, value: .zero)
        guard let pixels = malloc(size) else { return nil }
        guard let context = CGContext(
            data: pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * image.width,
            space: colorSpace!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: context.width, height: context.height), byTiling: false)
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
        let buffer = UnsafeMutableBufferPointer<Float32>.allocate(capacity: img.size * 4)
        for (i, pixel) in img.enumerated() {
            let srgb = pixel.toSRGB()
            let index = i * 4
            buffer[index] = srgb.x
            buffer[index+1] = srgb.y
            buffer[index+2] = srgb.z
            buffer[index+3] = 1
        }

        
        let data = Data(buffer: buffer)
        let img = MDLTexture(
            data: data,
            topLeftOrigin: true,
            name: destination.absoluteString,
            dimensions: SIMD2<Int32>(Int32(img.width), Int32(img.height)),
            rowStride: img.width * MemoryLayout<Float>.size * 4,
            channelCount: 4,
            channelEncoding: .float32,
            isCube: false
        )

        guard let url = URL(string: "file://\(destination.absoluteString)") else { return false }

        return img.write(to: url)
    }
}

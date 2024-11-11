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
    func read(file: URL) -> Array2d<Color>? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let size = cgImage.height * cgImage.width * 8
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
            dimensions: SIMD2<Int32>(Int32(img.xSize), Int32(img.ySize)),
            rowStride: img.xSize * MemoryLayout<Float>.size * 4,
            channelCount: 4,
            channelEncoding: .float32,
            isCube: false
        )

        guard let url = URL(string: "file://\(destination.absoluteString)") else { return false }

        return img.write(to: url)
    }
}

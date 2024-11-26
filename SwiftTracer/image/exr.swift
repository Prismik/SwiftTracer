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
        guard let data = texture.texelDataWithTopLeftOrigin(atMipLevel: 0, create: true) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return nil
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

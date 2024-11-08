//
//  imageFormat.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-11-07.
//

import Foundation

struct BitmapPixel {
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

protocol ImageEncoding {
    func read(file: URL) -> Array2d<Color>?
    func write(img: Array2d<Color>, to destination: URL) -> Bool
}

enum EncodingIdentifier {
    case png
    case jpg
    case pfm
    
    init?(filename: String) {
        switch filename.components(separatedBy: ".").last {
            case .some("png"): self = .png
            case .some("pfm"): self = .pfm
            case .some("jpg"): self = .jpg
            default: return nil
        }
    }
}

extension Color {
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

//
//  texture.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-20.
//

import Foundation

enum Texture {
    case constant(value: Color)
    case textureMap(values: Array2d<Color>, scale: Float, uvScale: Vec2, uvOffset: Vec2)
    case checkerboard2d(color1: Color, color2: Color, uvScale: Vec2, uvOffset: Vec2)
    
    /// Get the texture `Float` value at the given uv point `(R=G=B)`.
    func get(uv: Vec2, p: Point3) -> Float {
        let c: Color = get(uv: uv, p: p)
        return (c.x + c.y + c.z) / 3
    }

    /// Get the texture RGB components at the given uv point.
    func get(uv: Vec2, p: Point3) -> Color {
        let uv = Vec2(uv.x.modulo(1.0), uv.y.modulo(1.0))
        switch self {
        case .constant(let value):
            return value
        case let .textureMap(values, scale, uvScale, uvOffset):
            return bilinearInterpolate(uv: uv, values: values, scale: uvScale, offset: uvOffset) * scale
        case let .checkerboard2d(color1, color2, uvScale, uvOffset):
            let scaled = uv * uvScale + uvOffset
            let a = floor(scaled.x)
            let b = floor(scaled.y)
            return (a + b).isPair
                ? color1
                : color2
        }
    }
    
    
    private func bilinearInterpolate(uv: Vec2, values: Array2d<Color>, scale: Vec2, offset: Vec2) -> Color {
        let xy = uv.toXY(lengths: Vec2(Float(values.xSize), Float(values.ySize)), scale: scale, offset: offset)
        let p00 = Vec2(floor(xy.x), floor(xy.y))
        let p01 = Vec2(floor(xy.x), ceil(xy.y))
        let p10 = Vec2(ceil(xy.x), floor(xy.y))
        let p11 = Vec2(ceil(xy.x), ceil(xy.y))
        
        let xDistance = (p10.x - p00.x).abs()
        let yDistance = (p01.y - p00.y).abs()
        let a = (xy.x - p00.x) / xDistance
        let b = (xy.y - p00.y) / yDistance
        
        let rp00 = values.get(Int(p00.x), Int(p00.y))
        let rp01 = values.get(Int(p01.x), Int(p01.y))
        let rp10 = values.get(Int(p10.x), Int(p10.y))
        let rp11 = values.get(Int(p11.x), Int(p11.y))

        let lhs = (rp01 * (1 - a) + rp11 * a) * b
        let rhs = (rp00 * (1 - a) + rp10 * a) * (1 - b)
        return lhs + rhs
    }
}

extension Texture: Decodable {
    enum TypeIdentifier: String, Decodable {
        case constant
        case texture
        case checkerboardXY = "checkerboard2d"
    }


    enum CodingKeys: String, CodingKey {
        case type
        case filename
        
        // Texture
        case scale
        case uvScale = "uv_scale"
        case uvOffset = "uv_offset"
        case vflip

        // Checkerboards
        case color1
        case color2
    }
    
    init(from decoder: Decoder) throws {
        if let rawValueTexture = try? Texture.fromSingleValueRaw(decoder: decoder) {
            self = rawValueTexture
        } else if let rawFilenameTexture = try? Texture.fromSingleValueFilename(decoder: decoder) {
            self = rawFilenameTexture
        } else {
            // Decode json object
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(TypeIdentifier.self, forKey: .type)
            switch type {
            case .texture:
                // TODO File resolver
                let file = try container.decode(String.self, forKey: .filename)
                let scale = try container.decodeIfPresent(Float.self, forKey: .scale) ?? 1.0
                let uvScale = try container.decodeIfPresent(Vec2.self, forKey: .uvScale) ?? Vec2(repeating: 1)
                let uvOffset = try container.decodeIfPresent(Vec2.self, forKey: .uvOffset) ?? Vec2()
                let vflip = try container.decodeIfPresent(Bool.self, forKey: .vflip) ?? true
                guard let values = Image(filename: file)?.read() else { fatalError("Error while reading image \(file)") }
                if vflip {
                    values.flipVertically()
                }
                self = .textureMap(values: values, scale: scale, uvScale: uvScale, uvOffset: uvOffset)
            case .checkerboardXY:
                let color1 = try container.decodeIfPresent(Color.self, forKey: .color1) ?? Color()
                let color2 = try container.decodeIfPresent(Color.self, forKey: .color2) ?? Color(repeating: 1)
                let scale = try container.decodeIfPresent(Vec2.self, forKey: .uvScale) ?? Vec2(repeating: 1)
                let offset = try container.decodeIfPresent(Vec2.self, forKey: .uvOffset) ?? Vec2()
                self = .checkerboard2d(color1: color1, color2: color2, uvScale: scale, uvOffset: offset)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [CodingKeys.type], debugDescription: "Invalid texture type")
                )
            }
        }
    }
    
    /// Attempts decoding a texture as constant value using Float or Color decoding
    private static func fromSingleValueRaw(decoder: Decoder) throws -> Texture {
        let container = try decoder.singleValueContainer()
        do {
            let value = try container.decode(Float.self)
            return .constant(value: Color(repeating: value))
        } catch {
            let value = try container.decode(Color.self)
            return .constant(value: value)
        }
    }
    
    private static func fromSingleValueFilename(decoder: Decoder) throws -> Texture {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        return Texture.from(filename: value)
    }
    
    private static func from(filename: String) -> Texture {
        guard let values = Image(filename: filename)?.read() else { fatalError("Error while reading image \(filename)") }
        values.flipVertically()
        return .textureMap(values: values, scale: 1.0, uvScale: Vec2(repeating: 1), uvOffset: Vec2())
    }
}

private extension Vec2 {
    func toXY(lengths: Vec2, scale: Vec2, offset: Vec2) -> Vec2 {
        var uv = Vec2(self.x.modulo(1.0), self.y.modulo(1.0))
        uv = uv * scale + offset
        let xy = uv * Vec2(lengths.x - 1, lengths.y - 1)
        return Vec2(xy.x.modulo(lengths.x - 1), xy.y.modulo(lengths.y - 1))
    }
}

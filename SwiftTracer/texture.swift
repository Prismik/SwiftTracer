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
    case checkerboard3d(color1: Color, color2: Color, transform: Transform)
    
    func get(uv: Vec2, p: Point3) -> Float {
        let c: Color = get(uv: uv, p: p)
        return (c.x + c.y + c.z) / 3
    }

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
        case let .checkerboard3d(color1, color2, transform):
            let p = transform.point(p)
            let a = floor(p.x.abs())
            let b = floor(p.y.abs())
            let c = floor(p.z.abs())
            return (a + b + c).isPair
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
        case checkerboardXYZ = "checkerboard3d"
    }


    enum CodingKeys: String, CodingKey {
        case type
        case filename
        
        // Texture
        case scale
        case uvScale
        case uvOffset
        case vflip

        // Checkerboards
        case color1
        case color2
        case transform
    }
    
    init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(TypeIdentifier.self, forKey: .type)
            switch type {
            case .texture:
                // TODO File resolver
                let file = try container.decode(String.self, forKey: .filename)
                let scale = try container.decode(Float.self, forKey: .scale)
                let uvScale = try container.decode(Vec2.self, forKey: .uvScale)
                let uvOffset = try container.decode(Vec2.self, forKey: .uvOffset)
                let vflip = try container.decodeIfPresent(Bool.self, forKey: .vflip) ?? true
                guard var values = Image(filename: file)?.read() else { fatalError("Error while reading image \(file)") }
                if vflip {
                    values.flipVertically()
                }
                self = .textureMap(values: values, scale: scale, uvScale: uvScale, uvOffset: uvOffset)
            case .checkerboardXY:
                let color1 = try container.decode(Color.self, forKey: .color1)
                let color2 = try container.decode(Color.self, forKey: .color2)
                let scale = try container.decode(Vec2.self, forKey: .uvScale)
                let offset = try container.decode(Vec2.self, forKey: .uvOffset)
                self = .checkerboard2d(color1: color1, color2: color2, uvScale: scale, uvOffset: offset)
            case .checkerboardXYZ:
                let color1 = try container.decode(Color.self, forKey: .color1)
                let color2 = try container.decode(Color.self, forKey: .color2)
                let transform = try container.decode(Transform.self, forKey: .transform)
                self = .checkerboard3d(color1: color1, color2: color2, transform: transform)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [CodingKeys.type], debugDescription: "Invalid texture type")
                )
            }
        } catch {
            let container = try decoder.singleValueContainer()
            self = .constant(value: try container.decode(Color.self))
        }
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

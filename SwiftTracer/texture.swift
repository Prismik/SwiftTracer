//
//  texture.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-20.
//

import Foundation

enum Texture<T: Decodable> where T: SummableMultipliable {
    case constant(value: T)
    case textureMap(values: [T], scale: Float, uvScale: Vec2, uvOffset: Vec2)
    case checkerboard2d(color1: T, color2: T, uvScale: Vec2, uvOffset: Vec2)
    case checkerboard3d(color1: T, color2: T, transform: Transform)
    
    func get(uv: Vec2, p: Point3) -> T {
        switch self {
        case .constant(let value):
            return value
        case let .textureMap(values, _, _, _):
            return values[0]
        case let .checkerboard2d(color1, _, _, _):
            return color1
        case let .checkerboard3d(color1, _, _):
            return color1
        }
    }
}

extension Texture: Decodable {
    enum CodingKeys: String, CodingKey {
        case type
        case filename
    }
    
    init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "texture":
                // TODO File resolver
                let file = try container.decode(String.self, forKey: .filename)
                self = .textureMap(values: [], scale: 1, uvScale: Vec2(repeating: 1), uvOffset: Vec2())
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [CodingKeys.type], debugDescription: "Invalid texture type")
                )
            }
        } catch {
            let container = try decoder.singleValueContainer()
            self = .constant(value: try container.decode(T.self))
        }
    }
}

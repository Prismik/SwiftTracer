//
//  texture.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-20.
//

import Foundation

protocol SummableMultipliable: Equatable {
    static func +(lhs: Self, rhs: Self) -> Self
    static func *(lhs: Self, rhs: Self) -> Self
}

enum Texture<T> where T: SummableMultipliable {
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

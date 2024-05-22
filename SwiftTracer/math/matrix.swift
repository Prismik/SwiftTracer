//
//  matrix.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-17.
//

import Foundation
import simd

typealias Mat3 = simd_float3x3
typealias Mat4 = simd_float4x4

extension Mat3: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        let transpose = self.transpose
        try container.encode(contentsOf: [transpose[0], transpose[1], transpose[2]])
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var rows: [Vec3] = []
        rows.append(try container.decode(Vec3.self))
        rows.append(try container.decode(Vec3.self))
        rows.append(try container.decode(Vec3.self))
        self.init(rows: rows)
    }
    
    static func identity() -> Mat3 {
        return Mat3(diagonal: Vec3(repeating: 1))
    }
}

extension Mat4: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        let transpose = self.transpose
        try container.encode(contentsOf: [transpose[0], transpose[1], transpose[2], transpose[3]])
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var rows: [Vec4] = []
        rows.append(try container.decode(Vec4.self))
        rows.append(try container.decode(Vec4.self))
        rows.append(try container.decode(Vec4.self))
        rows.append(try container.decode(Vec4.self))
        self.init(rows: rows)
    }
    
    static func identity() -> Mat4 {
        return Mat4(diagonal: Vec4(repeating: 1))
    }
}

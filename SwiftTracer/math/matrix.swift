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

extension Mat4: Decodable {
    enum CodingKeys: String, CodingKey {
        case o
        case x
        case y
        case z
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let o = try container.decodeIfPresent(Vec3.self, forKey: .o) ?? Vec3()
            let x = try container.decodeIfPresent(Vec3.self, forKey: .x) ?? Vec3.unit(.x)
            let y = try container.decodeIfPresent(Vec3.self, forKey: .y) ?? Vec3.unit(.y)
            let z = try container.decodeIfPresent(Vec3.self, forKey: .z) ?? Vec3.unit(.z)
            
            var columns: [Vec4] = [
                Vec4(x.x, x.y, x.z, 0),
                Vec4(y.x, y.y, y.z, 0),
                Vec4(z.x, z.y, z.z, 0),
                Vec4(o.x, o.y, o.z, 1)
            ]
            self.init(columns)
        } else {
            var container = try decoder.unkeyedContainer()
            var rows: [Vec4] = []
            rows.append(try container.decode(Vec4.self))
            rows.append(try container.decode(Vec4.self))
            rows.append(try container.decode(Vec4.self))
            rows.append(try container.decode(Vec4.self))
            self.init(rows: rows)
        }
    }
    
    static func identity() -> Mat4 {
        return Mat4(diagonal: Vec4(repeating: 1))
    }
}

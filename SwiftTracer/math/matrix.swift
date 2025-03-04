//
//  matrix.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-17.
//

import Foundation
import simd

typealias Mat2 = simd_float2x2
typealias Mat3 = simd_float3x3
typealias Mat4 = simd_float4x4

extension Mat2 {
    var diagonal: Vec2 {
        return Vec2(self[0, 0], self[1, 1])
    }
}

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

extension Mat4: @retroactive Decodable {
    enum CodingKeys: String, CodingKey {
        case o
        case x
        case y
        case z
        
        // Angle axis
        case angle
        case axis
        
        // Scale
        case scale
        
        // Translate
        case translate
        
        // Rotate
        case rotation

        // From --> to
        case from
        case to
        case up
        case at
        
        // Matrix
        case matrix
    }
    
    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if container.contains(any: [.o, .x, .y, .z]) {
                let o = try container.decodeIfPresent(Vec3.self, forKey: .o) ?? Vec3()
                let x = try container.decodeIfPresent(Vec3.self, forKey: .x) ?? Vec3.unit(.x)
                let y = try container.decodeIfPresent(Vec3.self, forKey: .y) ?? Vec3.unit(.y)
                let z = try container.decodeIfPresent(Vec3.self, forKey: .z) ?? Vec3.unit(.z)
                
                let columns: [Vec4] = [
                    Vec4(x.x, x.y, x.z, 0),
                    Vec4(y.x, y.y, y.z, 0),
                    Vec4(z.x, z.y, z.z, 0),
                    Vec4(o.x, o.y, o.z, 1)
                ]
                self.init(columns)
            } else if container.contains(.scale) {
                do {
                    let singleValue = try container.decode(Float.self, forKey: .scale)
                    self.init(diagonal: Vec3(repeating: singleValue).extend(scalar: 1))
                } catch {
                    let value =  try container.decodeIfPresent(Vec3.self, forKey: .scale) ?? Vec3()
                    self.init(diagonal: value.extend(scalar: 1))
                }
            } else if container.contains(any: [.angle, .axis]) {
                let angle = try container.decodeIfPresent(Float.self, forKey: .angle) ?? 0
                let a = try container.decodeIfPresent(Vec3.self, forKey: .axis) ?? Vec3(1, 0, 0)
                let axis = a.normalized()
                let rad = angle.toRadians()
                let (sin, cos) = (rad.sin(), rad.cos())
                let subCos = 1 - cos
                self.init(
                    Vec4(subCos * axis.x * axis.x + cos, subCos * axis.x * axis.y + sin * axis.z, subCos * axis.x * axis.z - sin * axis.y, 0),
                    Vec4(subCos * axis.x * axis.y - sin * axis.z, subCos * axis.y * axis.y + cos, subCos * axis.y * axis.z + sin * axis.x, 0),
                    Vec4(subCos * axis.x * axis.z + sin * axis.y, subCos * axis.y * axis.z - sin * axis.x, subCos * axis.z * axis.z + cos, 0),
                    Vec4(0, 0, 0, 1)
                )
            } else if container.contains(.rotation) {
                var r = try container.decodeIfPresent(Vec3.self, forKey: .rotation) ?? Vec3()
                r = r * Float.pi / 180
                let c = Vec3(r.x.cos(), r.y.cos(), r.z.cos())
                let s = Vec3(r.x.sin(), r.y.sin(), r.z.sin())
                self = Mat4(
                    Vec4(
                        c.y * c.z - s.y * s.x * s.z,
                        -c.y * s.z - s.y * s.x * c.z,
                        -s.y * c.x,
                        0
                    ),
                    Vec4(c.x * s.z, c.x * c.z, -s.x, 0),
                    Vec4(
                        s.y * c.z + c.y * s.x * s.z,
                        -s.y * s.z + c.y * s.x * c.z,
                        c.y * c.x,
                        0
                    ),
                    Vec4(0, 0, 0, 1)
                ).transpose
            } else if container.contains(.translate) {
                let t = try container.decodeIfPresent(Vec3.self, forKey: .translate) ?? Vec3()
                self.init(
                    Vec4(1, 0, 0, 0),
                    Vec4(0, 1, 0, 0),
                    Vec4(0, 0, 1, 0),
                    Vec4(t.x, t.y, t.z, 1)
                )
            } else if container.contains(any: [.from, .to, .up, .at]) {
                let from = try container.decodeIfPresent(Vec3.self, forKey: .from) ?? Vec3.unit(.z)
                var to = try container.decodeIfPresent(Vec3.self, forKey: .to) ?? Vec3()
                to += try container.decodeIfPresent(Vec3.self, forKey: .at) ?? Vec3()
                var up = try container.decodeIfPresent(Vec3.self, forKey: .y) ?? Vec3.unit(.y)
                let dir = (from - to).normalized()
                let left = up.cross(dir).normalized()
                up = dir.cross(left).normalized()
                
                self.init(
                    left.extend(scalar: 0),
                    up.extend(scalar: 0),
                    dir.extend(scalar: 0),
                    from.extend(scalar: 1)
                )
            } else if container.contains(.matrix) {
                let values = try container.decode([Float].self, forKey: .matrix)
                self = Mat4(
                    Vec4(values[0], values[1], values[2], values[3]),
                    Vec4(values[4], values[5], values[6], values[7]),
                    Vec4(values[8], values[9], values[10], values[11]),
                    Vec4(values[12], values[13], values[14], values[15])
                ).transpose
            } else {
                var container = try decoder.unkeyedContainer()
                var rows: [Vec4] = []
                rows.append(try container.decode(Vec4.self))
                rows.append(try container.decode(Vec4.self))
                rows.append(try container.decode(Vec4.self))
                rows.append(try container.decode(Vec4.self))
                self.init(rows: rows)
            }
        } catch {
            // Try with raw
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

extension KeyedDecodingContainer {
    func contains(any keys: [K]) -> Bool {
        for key in keys {
            if contains(key) {
                return true
            }
        }
        
        return false
    }
}

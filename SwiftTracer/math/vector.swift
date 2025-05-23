//
//  Vector.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation
import simd

public typealias Point3 = simd_float3
public typealias Vec2 = simd_float2
public typealias Vec3 = simd_float3
public typealias Vec4 = simd_float4
public typealias Color = simd_float3

struct Frame {
    let x: Vec3
    let y: Vec3
    let z: Vec3
    
    
    /// Based on "Building an Orthonormal Basis, Revisited" by
    /// Tom Duff, James Burgess, Per Christensen, Christophe Hery, Andrew Kensler,
    /// Max Liani, and Ryusuke Villemin
    /// https://graphics.pixar.com/library/OrthonormalB/paper.pdf
    init(n: Vec3) {
        let sign: Float = n.z >= 0 ? 1.0 : -1.0
        let a = -1 / (sign + n.z)
        let b = n.x * n.y * a
        let x = Vec3(1 + sign * n.x * n.x * a, sign * b, -sign * n.x)
        let y = Vec3(b, sign + n.y * n.y * a, -n.y)

        self.x = x
        self.y = y
        self.z = n
    }

    func toWorld(v: Vec3) -> Vec3 {
        return self.x * v.x + self.y * v.y + self.z * v.z
    }
    
    func toLocal(v: Vec3) -> Vec3 {
        Vec3(
            v.dot(x),
            v.dot(y),
            v.dot(z)
        )
    }
}

extension Vec2 {
    enum CodingKeys: String, CodingKey {
        case x
        case y
    }
    
    
    var length: Float {
        return simd.length(self)
    }
    
    var lengthSquared: Float {
        return simd.length_squared(self)
    }
}

extension Vec3: @retroactive AdditiveArithmetic where Scalar: BinaryFloatingPoint {
    enum Axis {
        case x
        case y
        case z
    }

    public static var zero: Vec3 {
        return Vec3()
    }

    var length: Float {
        return simd.length(self)
    }
    
    var lengthSquared: Float {
        return simd.length_squared(self)
    }
    
    func dot(_ other: Vec3) -> Scalar {
        return simd_dot(self, other)
    }
    
    func cross(_ other: Vec3) -> Vec3 {
        return simd_cross(self, other)
    }
    
    func normalized() -> Vec3 {
        return simd_normalize(self)
    }
    
    func extend(scalar: Float) -> Vec4 {
        return Vec4(self[0], self[1], self[2], scalar)
    }
    
    func reflect(n: Vec3) ->  Vec3 {
        return simd_reflect(self, n)
    }
    
    func refract(n: Vec3, eta: Float) -> Vec3 {
        return simd_refract(self, n, eta)
    }
    
    func safeSqrt() -> Vec3 {
        return Vec3(x.sqrt(), y.sqrt(), z.sqrt())
    }

    static func unit(_ axis: Axis) -> Vec3 {
        switch axis {
        case .x: return Vec3(1, 0, 0)
        case .y: return Vec3(0, 1, 0)
        case .z: return Vec3(0, 0, 1)
        }
    }
}

extension Vec4 {
    func truncate() -> Vec3 {
        return Vec3(self[0], self[1], self[2])
    }
}

extension Point3 {
    func distance(_ other: Point3) -> Scalar {
        return simd_distance(self, other)
    }
    
    func distance2(_ other: Point3) -> Scalar {
        return simd_distance_squared(self, other)
    }
    
    static func fromHomogeneous(vector v: Vec4) -> Point3 {
        let e = v.truncate() * (1 / v.w)
        return Point3(e.x, e.y, e.z)
    }
    
    
    func toHomogeneous() -> Vec4 {
        return Vec4(self.x, self.y, self.z, 1)
    }
}

extension Color {
    var luminance: Float {
        return self.dot(Color(0.212671, 0.715160, 0.072169))
    }
    
    var hasNaN: Bool {
        return x.isNaN || y.isNaN || z.isNaN
    }
    
    var hasColor: Bool {
        return x.isFinite && !x.isZero && y.isFinite && !y.isZero && z.isFinite && !z.isZero
    }
    
    var isFinite: Bool {
        return x.isFinite && y.isFinite && z.isFinite
    }
    
    /// Replaces NaN in the rgb channels with `zero`.
    var sanitized: Self {
        var result = self
        
        if x != x { result.x = 0 }
        if y != y { result.y = 0 }
        if z != z { result.z = 0 }
        return result
    }
    
    /// Returns a copy of `self` where the values are replaced by their absolute values.
    var abs: Self {
        return Color(x.abs(), y.abs(), z.abs())
    }
}

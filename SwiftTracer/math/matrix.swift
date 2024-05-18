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

extension Mat3 {
    init(someVAl: Int) {
        self.init()
    }

    /*
    static func * (lhs: Self, rhs: Vec3) -> Vec3 {
        return Vec3(
            lhs[0][0] * rhs[0] + lhs[1][0] * rhs[1] + lhs[2][0] * rhs[2],
            lhs[0][1] * rhs[0] + lhs[1][1] * rhs[1] + lhs[2][1] * rhs[2],
            lhs[0][2] * rhs[0] + lhs[1][2] * rhs[1] + lhs[2][2] * rhs[2]
        )
    }
     */
}

extension Mat4 {
    func inverse() throws -> Mat4 {
        if self.determinant == 0 {
            throw MathError.notInvertible
        }
        
        return self.inverse
    }
}

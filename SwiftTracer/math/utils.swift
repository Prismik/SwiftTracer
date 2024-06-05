//
//  utils.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-20.
//

import Foundation

enum Utils {
    static func directionFrom(phi: Float, theta: Float) -> Vec3 {
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        
        return Vec3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta)
    }
    
    static func sphericalCoordinatesFrom(direction: Vec3) -> (Float, Float) {
        return (atan2f(-direction.y, -direction.x) + Float.pi, direction.z.acos())
    }
}

extension Float {
    var isPair: Bool {
        return self.truncatingRemainder(dividingBy: 2) == 0
    }

    func toRadians() -> Self {
        return self * Float.pi / 180
    }
    
    func clamped(_ lower: Float, _ upper: Float) -> Float {
        return min(max(lower, self), upper)
    }
    
    func pow(_ n: Float) -> Float {
        return Darwin.pow(self, n)
    }
    
    func acos() -> Float {
        return Darwin.acos(self)
    }
    
    func cos() -> Float {
        return Darwin.cos(self)
    }
    
    func sin() -> Float {
        return Darwin.sin(self)
    }
    
    func abs() -> Float {
        return Swift.abs(self)
    }
    
    func modulo(_ other: Float) -> Float {
        let r = self.truncatingRemainder(dividingBy: other)
        return r < 0
            ? r + other
            : r
    }
}

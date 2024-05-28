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
        return (atan2f(-direction.y, -direction.x) + Float.pi, acos(direction.z))
    }
}

extension Float {
    func toRadians() -> Self {
        return self * Float.pi / 180
    }
}

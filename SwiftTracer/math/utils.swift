//
//  utils.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-20.
//

import Algorithms
import Foundation
import Progress
import simd

enum Utils {
    static func directionFrom(phi: Float, theta: Float) -> Vec3 {
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        
        return Vec3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta)
    }
    
    static func sphericalCoordinatesFrom(direction: Vec3) -> (Float, Float) {
        let t = direction.z.clamped(-1, 1).acos()
        return (atan2f(-direction.y, -direction.x) + .pi, t)
    }
    
    static func pixelToDirection(p: Vec2, imageSize: Vec2) -> Vec3 {
        return directionFrom(
            phi: p.x * 2 * .pi / imageSize.x,
            theta: p.y * .pi / imageSize.y
        )
    }
    
    static func directionToPixel(d: Vec3, imageSize: Vec2) -> Vec2 {
        let sc = sphericalCoordinatesFrom(direction: d)
        return Vec2(
            sc.0 * imageSize.x / (2 * .pi),
            sc.1 * imageSize.y / .pi
        )
    }
    
    /// Solves a quadratic equation, returning optional whenever no roots can be found.
    static func solve(a: Float, b: Float, c: Float) -> (Float, Float)? {
        let discriminant = b * b - 4 * a * c
        switch(discriminant) {
        case let x where x.isLess(than: 0): // No roots
            return nil
        default:
            let rootDiscriminant = discriminant.sqrt()
            let q = b < 0
                ? -0.5 * (b - rootDiscriminant)
                : -0.5 * (b + rootDiscriminant)
            
            let x0 = q / a
            let x1 = c / q
            return if x0 > x1 { (x1, x0) } else { (x0, x1) }
        }
    }
}

extension RandomAccessCollection where Element: Comparable {
    func binarySearch(_ element: Element) -> (index: Index, found: Bool) {
        let index = partitioningIndex(where: { $0 >= element })
        let found = index != endIndex && self[index] == element
        return (index, found)
    }
}

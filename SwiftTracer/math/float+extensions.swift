//
//  float+extension.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-10.
//

import Foundation

extension Float {
    /// Returns true if float is pair.
    var isPair: Bool {
        return self.truncatingRemainder(dividingBy: 2) == 0
    }

    /// Converts a degrees andle to a radians angle.
    func toRadians() -> Self {
        return self * .pi / 180
    }
    
    /// Converts a radians andle to a degrees angle.
    func toDegrees() -> Self {
        return self * 180 / .pi
    }
    
    /// Ensures the value will be brought back betwee the range (lower ... upper).
    func clamped(_ lower: Float, _ upper: Float) -> Float {
        let t = self < lower ? lower : self
        return t > upper ? upper : t
    }
    
    func pow(_ n: Float) -> Float {
        #if os(Linux)
            return Glibc.pow(self, n)
        #else
            return Darwin.pow(self, n)
        #endif
        
    }
    
    func acos() -> Float {
        #if os(Linux)
            return Glibc.acos(self)
        #else
            return Darwin.acos(self)
        #endif
    }
    
    func cos() -> Float {
        #if os(Linux)
            return Glibc.cos(self)
        #else
            return Darwin.cos(self)
        #endif
    }
    
    func sin() -> Float {
        #if os(Linux)
            return Glibc.sin(self)
        #else
            return Darwin.sin(self)
        #endif
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
    
    func sqrt() -> Float {
        return max(0, squareRoot())
    }
}

//
//  sampling.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-20.
//

import Foundation


/// Contains sampler functions
enum Sample {
    static func spherical(sample: Vec2) -> Vec3 {
        let theta = acos(2 * sample.x - 1)
        let phi = 2 * Float.pi * sample.y
        
        return Utils.directionFrom(phi: phi, theta: theta)
    }
    
    static func hemisphere(sample: Vec2) -> Vec3 {
        let theta = acos(sample.x)
        let phi = 2 * Float.pi * sample.y
        
        return Utils.directionFrom(phi: phi, theta: theta)
    }
    
    static func cosineHemisphere(sample: Vec2) -> Vec3 {
        let theta = acos(sample.x.squareRoot())
        let phi = 2 * Float.pi * sample.y
        return Utils.directionFrom(phi: phi, theta: theta)
    }
}

/// Contains probability distribution functions
enum Pdf {
    static func spherical(_ v: Vec3) -> Float {
        return 1 / (4.0 * Float.pi)
    }
    
    static func hemisphere(v: Vec3) -> Float {
        guard v.z >= 0 else { return 0 }
        return 1 / (2.0 *  Float.pi)
    }
    
    static func cosineHemisphere(v: Vec3) -> Float {
        guard v.z >= 0 else { return 0 }
        let (_, theta) = Utils.sphericalCoordinatesFrom(direction: v)
        return cos(theta) / Float.pi
    }
}

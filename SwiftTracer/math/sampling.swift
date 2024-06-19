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
        let theta = (2 * sample.x - 1).acos()
        let phi = 2 * .pi * sample.y
        
        return Utils.directionFrom(phi: phi, theta: theta)
    }
    
    static func hemisphere(sample: Vec2) -> Vec3 {
        let theta = sample.x.acos()
        let phi = 2 * .pi * sample.y
        
        return Utils.directionFrom(phi: phi, theta: theta)
    }
    
    static func cosineHemisphere(sample: Vec2) -> Vec3 {
        let theta = sample.x.sqrt().acos()
        let phi = 2 * .pi * sample.y
        return Utils.directionFrom(phi: phi, theta: theta)
    }
    
    static func cosineHemispherePower(sample: Vec2, power: Float) -> Vec3 {
        let theta = sample.x.pow(1 / (1 + power)).acos()
        let phi: Float = 2 * .pi * sample.y
        return Utils.directionFrom(phi: phi, theta: theta)
    }
    
    static func cone(sample: Vec2, thetaMax: Float) -> Vec3 {
        let theta = (1 + (thetaMax.cos() - 1) * sample.x).acos()
        let phi: Float = 2 * .pi * sample.y
        return Utils.directionFrom(phi: phi, theta: theta)
    }
}

/// Contains probability distribution functions
enum Pdf {
    static func spherical(_ v: Vec3) -> Float {
        return 1 / (4.0 * .pi)
    }
    
    static func hemisphere(v: Vec3) -> Float {
        guard v.z >= 0 else { return 0 }
        return 1 / (2.0 *  .pi)
    }
    
    static func cosineHemisphere(v: Vec3) -> Float {
        guard v.z >= 0 else { return 0 }
        let (_, theta) = Utils.sphericalCoordinatesFrom(direction: v)

        return theta.cos() / .pi
    }
    
    static func cosineHemispherePower(v: Vec3, power: Float) -> Float {
        guard v.z >= 0 else { return 0 }
        let (_, theta) = Utils.sphericalCoordinatesFrom(direction: v)
        return (1 + power) * theta.cos().pow(power) / (2 * .pi)
    }
    
    static func cone(v: Vec3, thetaMax: Float) -> Float {
        guard v.z >= 0 else { return 0 }
        let (_, theta) = Utils.sphericalCoordinatesFrom(direction: v)
        guard theta <= thetaMax else { return 0 }
        return 1 / (2 * .pi * (1 - thetaMax.cos()))
    }
}

//
//  intersection.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-20.
//

import Foundation

struct Intersection {
    /// Intersection distance
    let t: Float
    
    /// Point of intersection TODO is it world or local
    let p: Point3
    
    /// Surface normal
    let n: Vec3
    
    let material: Material
    
    let shape: Shape
}

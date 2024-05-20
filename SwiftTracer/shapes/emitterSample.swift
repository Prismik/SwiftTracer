//
//  emitterSample.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-20.
//

import Foundation

// TODO Why is it talking about p; investigate
struct EmitterSample {
    /// Position on the light source
    let y: Point3
    /// Normal associated with p
    let n: Vec3
    /// UV coordinates associated with p
    let uv: Vec2
    /// Probability density (in solid angle)
    let pdf: Float
}

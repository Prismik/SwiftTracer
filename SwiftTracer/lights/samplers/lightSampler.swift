//
//  lightSampler.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-14.
//

import Foundation

struct SampledLight {
    let light: Light
    let prob: Float
    let s: Float
}

protocol LightSampler {
    /// Samples a light for a specific point
    func sample(context: LightSample.Context, sample: Float) -> SampledLight?
    
    /// Samples a light independantly of a specific point being illuminated.
    func sample(sample: Float) -> SampledLight?
    
    /// Probability mass function for a specific point
    func pmf(context: LightSample.Context, light: Light) -> Float
    
    /// Probability mass function independantly of a specific point being illuminated.
    func pmf(light: Light) -> Float
    
    var lights: [Light] { get }
}

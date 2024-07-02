//
//  uniform.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-14.
//

import Foundation

class UniformLightSampler: LightSampler {
    let lights: [Light]

    init(lights: [Light]) {
        self.lights = lights
    }

    func sample(context: LightSample.Context, sample: Float) -> SampledLight? {
        return self.sample(sample: sample)
    }
    
    func sample(sample: Float) -> SampledLight? {
        guard !lights.isEmpty else { return nil }
        let n = Float(lights.count)
        let index = min(floor(sample * n), n - 1)
        let prob: Float = 1 / n
        let s = sample * n - index
        return SampledLight(light: lights[Int(index)], prob: prob, s: s)
    }
    
    func pmf(context: LightSample.Context, light: any Light) -> Float {
        return pmf(light: light)
    }
    
    func pmf(light: any Light) -> Float {
        guard !lights.isEmpty else { return 0 }
        return 1 / Float(lights.count)
    }
    

}

//
//  uniform.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-14.
//

import Foundation

class UniformLightSampler: LightSampler {
    private let lights: [Light]

    init(lights: [Light]) {
        self.lights = lights
    }

    func sample(context: LightSample.Context, sample: Float) -> SampledLight? {
        return self.sample(sample: sample)
    }
    
    func sample(sample: Float) -> SampledLight? {
        guard !lights.isEmpty else { return nil }
        let index = min(Int(sample) * lights.count, lights.count - 1)
        let prob: Float = 1 / Float(lights.count)
        return SampledLight(light: lights[index], prob: prob)
    }
    
    func pmf(context: LightSample.Context, light: any Light) -> Float {
        return pmf(light: light)
    }
    
    func pmf(light: any Light) -> Float {
        guard !lights.isEmpty else { return 0 }
        return 1 / Float(lights.count)
    }
    

}

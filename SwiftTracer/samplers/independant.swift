//
//  independant.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import Foundation

final class IndependantSampler: Sampler {
    let nbSamples: Int = 12

    func next() -> Float {
        return gen()
    }
    
    func next2() -> Vec2 {
        return Vec2(gen(), gen())
    }
    
    private func gen() -> Float {
        Float.random(in: 0 ... 1)
    }
}

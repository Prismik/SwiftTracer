//
//  independent.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import Foundation

final class IndependentSampler: Sampler {
    let nbSamples: Int
    var rng: RNG = RNG()
    init(nspp: Int = 20) {
        self.nbSamples = nspp
    }

    func next() -> Float {
        return gen()
    }
    
    func next2() -> Vec2 {
        return Vec2(gen(), gen())
    }
    
    func gen() -> Float {
        Float.random(in: 0 ..< 100, using: &rng) / 100
    }
    
    func copy() -> IndependentSampler {
        let new = IndependentSampler(nspp: self.nbSamples)
        new.rng.state = rng.state
        return new
    }
    
    func new(nspp: Int) -> IndependentSampler {
        let new = IndependentSampler(nspp: nspp)
        return new
    }
}

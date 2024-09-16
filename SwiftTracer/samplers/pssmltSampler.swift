//
//  pssmltSampler.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-09-10.
//

import Foundation

final class PSSMLTSampler: Sampler {
    private enum Step {
        case small
        case large
    }

    private final class PrimarySample {
        var value: Float
        /// `time` value when this sample was modified most recently.
        var modify: Int
        
        init(value: Float) {
            self.value = value
            self.modify = 0
        }
    }
    
    var nbSamples: Int = 0
    
    private var sampleIndex = 0

    private var step: Step = .small

    private let largeStepRatio: Float = 0.3
    private var largeStepTime = 0
    
    /// Number of accepted mutations
    private var time = 0
    
    private var u: [PrimarySample] = []
    private var states: [(Int, PrimarySample)] = []
    
    private let s1: Float = 1 / 1024
    private let s2: Float = 1 / 64
    private lazy var logRatio = -log(s2/s1)
    
    func accept() {
        if step == .large {
            largeStepTime = time
        }
        
        time += 1
        states.removeAll()
        sampleIndex = 0
    }
    
    func reject() {
        for i in 0 ..< states.count {
            u[states[i].0] = states[i].1
        }
        
        states.removeAll()
        sampleIndex = 0
    }

    func reset() {
        time = 0
        sampleIndex = 0
        largeStepTime = 0
        u.removeAll()
    }

    func next() -> Float {
        let rng = primarySpaceGen(i: sampleIndex)
        sampleIndex += 1
        return rng
    }
    
    func next2() -> Vec2 {
        return Vec2(next(), next())
    }

    private func gen() -> Float {
        Float.random(in: 0 ... 1)
    }
    
    private func primarySpaceGen(i: Int) -> Float {
        while i >= u.count {
            u.append(PrimarySample(value: gen()))
        }

        guard u[i].modify < time else { return u[i].value }

        if step == .large {
            states.append((i, u[i]))
            u[i].modify = time
            u[i].value = gen()
        } else {
            if u[i].modify < largeStepTime {
                u[i].modify = largeStepTime
                u[i].value = gen()
            }
            
            while u[i].modify < time - 1 {
                u[i].modify += 1
                u[i].value = mutate(sample: u[i].value)
            }
            
            states.append((i, u[i]))
            u[i].modify += 1
            u[i].value = mutate(sample: u[i].value)
        }
        
        return u[i].value
    }
    
    private func mutate(sample: Float) -> Float {
        var result = sample
        let rng = gen()
        let dv = s2 * exp(logRatio * rng)
        if rng < 0.5 {
            result += dv
            if result > 1 { result -= 1 }
        } else {
            result -= dv
            if result < 0 { result += 1 }
        }
        
        return result
    }
}

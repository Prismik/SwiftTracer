//
//  pssmltSampler.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-09-10.
//

import Foundation

final class PSSMLTSampler: Sampler {
    struct Stats {
        var times: Int
        var accept: Int
        var reject: Int
    }

    enum Step {
        case small
        case large
    }

    private struct PrimarySample {
        var value: Float
        /// `time` value when this sample was modified most recently.
        var modify: Int
        
        init(value: Float) {
            self.value = value
            self.modify = 0
        }
    }
    
    static var count = 0
    var id: Int = 0
    var nbSamples: Int
    
    var step: Step = .small {
        didSet {
            if step == .small {
                smallStats.times += 1
            } else {
                largeStats.times += 1
            }
        }
    }
    let largeStepRatio: Float
    
    var rng: RNG = RNG()

    private var sampleIndex = 0
    private var largeStepTime = 0
    
    /// Number of accepted mutations
    private var time = 0
    
    private var u: [PrimarySample] = []
    private var backup: [(Int, PrimarySample)] = []
    
    private let s1: Float = 1 / 1024
    private let s2: Float = 1 / 64
    private lazy var logRatio = -log(s2/s1)
    
    var smallStats = Stats(times: 0, accept: 0, reject: 0)
    var largeStats = Stats(times: 0, accept: 0, reject: 0)

    init(nbSamples: Int, largeStepRatio: Float = 0.3) {
        self.nbSamples = nbSamples
        self.largeStepRatio = largeStepRatio
    }

    // TODO Make sure the new instence maintains integrity of the vectors
    func new() -> Self {
        return .init(nbSamples: self.nbSamples, largeStepRatio: self.largeStepRatio)
    }

    func accept() {
        if step == .large {
            largeStepTime = time
            largeStats.accept += 1
        } else {
            smallStats.accept += 1
        }
        
        time += 1
        backup.removeAll()
        sampleIndex = 0
    }
    
    func reject() {
        for (i, v) in backup {
            u[i] = v
        }
        
        if step == .large {
            largeStats.reject += 1
        } else {
            smallStats.reject += 1
        }
        
        backup.removeAll()
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

    func gen() -> Float {
        Float.random(in: 0 ... 1, using: &rng)
    }
    
    // TODO Add init with nb samples and copy value here
    func clone() -> PSSMLTSampler {
        let newSampler = PSSMLTSampler(nbSamples: nbSamples)
        newSampler.id = PSSMLTSampler.count + 1
        PSSMLTSampler.count += 1
        return newSampler
    }

    private func primarySpaceGen(i: Int) -> Float {
        while i >= u.count {
            u.append(PrimarySample(value: gen()))
        }

        guard u[i].modify < time else { return u[i].value }

        if step == .large {
            backup.append((i, u[i]))
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
            
            backup.append((i, u[i]))
            u[i].modify += 1
            u[i].value = mutate(sample: u[i].value)
        }
        
        return u[i].value
    }
    
    private func mutate(sample: Float) -> Float {
        var result = sample
        var rng = gen()
        let add: Bool
        if self.gen() < 0.5 {
            add = true
            rng *= 2
        } else {
            add = false
            rng = 2 * (rng - 0.5)
        }
        
        let dv = s2 * exp(logRatio * rng)
        if add {
            result += dv
            if result > 1 { result -= 1 }
        } else {
            result -= dv
            if result < 0 { result += 1 }
        }
        
        assert(result < 1)
        assert(result >= 0)
        return result
    }
}

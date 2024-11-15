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

    enum Mutation {
        case kelemen(sampler: Sampler, s2: Float, logRatio: Float)
        case mitsuba(sampler: Sampler)
        
        func mutate(value: Float) -> Float {
            var result = value
            switch self {
            case let .kelemen(sampler, s2, logRatio):
                var rand = sampler.gen()
                let add: Bool
                if rand < 0.5 {
                    add = true
                    rand *= 2
                } else {
                    add = false
                    rand = 2 * (rand - 0.5)
                }
                
                let dv = s2 * exp(rand * logRatio)
                if add {
                    result += dv
                    if result > 1 { result -= 1 }
                } else {
                    result -= dv
                    if result < 0 { result += 1 }
                }
            case .mitsuba(let sampler):
                let temp: Float = sqrt(-2 * log(1 - sampler.gen()))
                let dv = temp * (2.0 * Float.pi * sampler.gen()).cos()
                result = (result + 1e-2 * dv).modulo(1.0)
            }
            
            return result
        }
    }

    enum Step {
        case small
        case large
    }

    struct PrimarySample {
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
    var sampleIndex = 0
    var replay: [Float] = []
    private var largeStepTime = 0
    
    /// Number of accepted mutations
    private var time = 0
    
    private var u: [PrimarySample] = []
    private var backup: [(Int, PrimarySample)] = []
    
    private let s1: Float = 1 / 1024
    private let s2: Float = 1 / 64
    private lazy var logRatio = -log(s2/s1)
    private lazy var mutator: Mutation = .kelemen(sampler: self, s2: s2, logRatio: logRatio)
    var smallStats = Stats(times: 0, accept: 0, reject: 0)
    var largeStats = Stats(times: 0, accept: 0, reject: 0)

    init(nbSamples: Int, largeStepRatio: Float = 0.3) {
        self.nbSamples = nbSamples
        self.largeStepRatio = largeStepRatio
    }

    func copy() -> PSSMLTSampler {
        let copy = PSSMLTSampler(nbSamples: self.nbSamples, largeStepRatio: self.largeStepRatio)
        copy.sampleIndex = sampleIndex
        copy.u = u
        copy.backup = backup
        copy.time = time
        copy.largeStepTime = largeStepTime
        copy.rng.state = rng.state
        return copy
    }
    
    func new(nspp: Int) -> Self {
        return .init(nbSamples: nspp, largeStepRatio: self.largeStepRatio)
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

    // TODO Find a way to uniform [0 ... 100(, which includes 99.99999999999999 and so on.
    func gen() -> Float {
        Float.random(in: 0 ..< 100, using: &rng) / 100
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
                u[i].value = mutator.mutate(value: u[i].value)
            }
            
            backup.append((i, u[i]))
            u[i].modify += 1
            u[i].value = mutator.mutate(value: u[i].value)
        }
        
        let value = u[i].value
        replay.append(value)
        return value
    }
}

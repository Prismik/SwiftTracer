//
//  replay.swift
//  SwiftTracer
//
//  Created by Francis on 2024-11-15.
//

final class ReplaySampler: Sampler {
    var nbSamples: Int { sampler.nbSamples }
    var rng: RNG {
        get { sampler.rng }
        set { sampler.rng = newValue }
    }
    
    let sampler: Sampler
    var random: [Float]
    var index: Int = 0
    
    init(sampler: Sampler, random: [Float]) {
        self.sampler = sampler
        self.random = random
    }
    
    func next() -> Float {
        return gen()
    }
    
    func next2() -> Vec2 {
        return Vec2(gen(), gen())
    }
    
    func gen() -> Float {
        guard index < random.count else {
            let next = sampler.next()
            index += 1
            random.append(next)
            return next
        }
        
        let next = random[index]
        index += 1
        return next
    }
    
    // TODO
    func copy() -> Self {
        fatalError("Not implemented")
    }
    
    // TODO
    func new(nspp: Int) -> Self {
        fatalError("Not implemented")
    }
}

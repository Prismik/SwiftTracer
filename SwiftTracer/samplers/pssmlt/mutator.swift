//
//  mutator.swift
//  SwiftTracer
//
//  Created by Francis on 2025-01-23.
//

import Foundation

struct AnyMutator: Decodable {
    enum TypeIdentifier: String, Codable {
        case kelemen
        case mitsuba
        case mala
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        // Kelemen mutation size parameters
        case s1
        case s2
        // Mala mutation parameters
        case step
    }
    
    let wrapped: PrimarySpaceMutation
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TypeIdentifier.self, forKey: .type)
        switch type {
        case .kelemen:
            let s1 = try container.decode(Float.self, forKey: .s1)
            let s2 = try container.decode(Float.self, forKey: .s2)
            
            self.wrapped = KelemenMutation(s1: s1, s2: s2)
        case .mitsuba:
            self.wrapped = MitsubaMutation()
        case .mala:
            self.wrapped = MalaMutation()
        }
    }
}

protocol PrimarySpaceMutation {
    var sampler: Sampler! { get set }

    // Check if can be brought back as a simpler api
    //func mutate(value: Float) -> Float
    func mutate(u: [PSSMLTSampler.PrimarySample], i: Int) -> Float
}

final class KelemenMutation: PrimarySpaceMutation {
    weak var sampler: Sampler!
    
    private let s1: Float
    private let s2: Float
    private let logRatio: Float
    
    init(s1: Float = 1 / 1024, s2: Float = 1 / 64) {
        self.s1 = s1
        self.s2 = s2
        
        self.logRatio = -log(s2/s1)
    }
    
    func mutate(value: Float) -> Float {
        var result = value
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
        
        return result
    }
    
    func mutate(u: [PSSMLTSampler.PrimarySample], i: Int) -> Float {
        return mutate(value: u[i].value)
    }
}

final class MitsubaMutation: PrimarySpaceMutation {
    weak var sampler: Sampler!

    func mutate(value: Float) -> Float {
        var result = value
        let temp: Float = sqrt(-2 * log(1 - sampler.gen()))
        let dv = temp * (2.0 * Float.pi * sampler.gen()).cos()
        result = (result + 1e-2 * dv).modulo(1.0)

        return result
    }
    
    func mutate(u: [PSSMLTSampler.PrimarySample], i: Int) -> Float {
        return mutate(value: u[i].value)
    }
}

final class MalaMutation: PrimarySpaceMutation {
    weak var sampler: Sampler!

    private var gradients: [Float] = [0, 0]
    private var rng2: Vec2? = nil
    private var step: Float = 0.1
    
    func setup(step: Float, gradient: Vec2) {
        self.step = step
        self.gradients = [gradient.x, gradient.y]
        self.rng2 = nil
    }

    func mutate(value: Float) -> Float {
        return 0
    }
    
    func mutate(u: [PSSMLTSampler.PrimarySample], i: Int) -> Float {
        guard let gradient = gradients[safe: i] else {
            let w: Float = gaussian(mean: u[i].value, sigma: step)
            var result: Float = u[i].value + step.sqrt() * w
            //if result > 1 { result -= 1 }
            //if result < 0 { result += 1 }

            return result.modulo(1.0).abs()
        }
        let mean = u[i].value - 0.5 * step * gradient
        rng2 = rng2 ?? gaussian(mean: mean, sigma: step)
        let w = rng2?[i] ?? 0
        var result = mean + step.sqrt() * w
        //if result > 1 { result -= 1 }
        //if result < 0 { result += 1 }

        return result.modulo(1.0).abs()
    }
    
    /// Returns a 2D sample proportional to a gausian distribution with `mean` and `sigma` standard deviation.
    private func gaussian(mean: Float, sigma: Float) -> Vec2 {
        var u1: Float
        repeat {
            u1 = Float.random(in: 0 ... 1)
        } while (u1 == 0)
        let u2 = Float.random(in: 0 ... 1)

        let mag = sigma * (-2 * log(u1)).sqrt()
        
        let z0: Float  = mag * (2 * .pi * u2).cos() + mean;
        let z1: Float  = mag * (2 * .pi * u2).sin() + mean;
        
        return Vec2(z0, z1)
    }
    
    /// Returns a 1D sample proportional to a gausian distribution with `mean` and `sigma` standard deviation.
    private func gaussian(mean: Float, sigma: Float) -> Float {
        var u1: Float
        repeat {
            u1 = Float.random(in: 0 ... 1)
        } while (u1 == 0)
        
        let u2 = Float.random(in: 0 ... 1)
        let z1 = (-2 * log(u1)).sqrt() * (2 * .pi * u2).cos()

        return mean + z1 * sigma
    }
}

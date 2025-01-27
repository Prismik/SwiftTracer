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

    func mutate(value: Float) -> Float
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

    var gradients: [Float] = []

    private var fallback = MitsubaMutation()
    private var step: Float = 0.1
    
    func setup(step: Float, gradient: Vec2) {
        self.step = step
        self.gradients = [gradient.x, gradient.y]
    }

    func mutate(value: Float) -> Float {
        if fallback.sampler == nil { fallback.sampler = sampler }
        return fallback.mutate(value: value)
    }
    
    func mutate(u: [PSSMLTSampler.PrimarySample], i: Int) -> Float {
        guard let gradient = gradients[safe: i] else { return mutate(value: u[i].value) }
        return (u[i].value + 0.5 * step * gradient + step.sqrt() * sampler.gen()).modulo(1.0)
    }
}

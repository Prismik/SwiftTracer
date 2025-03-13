//
//  mutator.swift
//  SwiftTracer
//
//  Created by Francis on 2025-01-23.
//

import Foundation
import simd

struct AnyMutator: Decodable {
    enum TypeIdentifier: String, Codable {
        case kelemen
        case mitsuba
        case mala
        case adaptiveMala = "adaptive_mala"
        case stratified
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        // Kelemen mutation size parameters
        case s1
        case s2
        // Mala mutation parameters
        case step
    }
    
    let wrapped: PrimarySpaceMutation.Type
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TypeIdentifier.self, forKey: .type)
        switch type {
        case .kelemen:
            self.wrapped = KelemenMutation.self
        case .mitsuba:
            self.wrapped = MitsubaMutation.self
        case .mala:
            self.wrapped = MalaMutation.self
        case .adaptiveMala:
            self.wrapped = MalaAdamMutation.self
        case .stratified:
            self.wrapped = StratifiedMutation.self
        }
    }
}

protocol PrimarySpaceMutation {
    var sampler: Sampler! { get set }

    init()

    // Check if can be brought back as a simpler api
    //func mutate(value: Float) -> Float
    func mutate(u: [PSSMLTSampler.PrimarySample], i: Int) -> Float
}

final class KelemenMutation: PrimarySpaceMutation {
    weak var sampler: Sampler!
    
    private let s1: Float
    private let s2: Float
    private let logRatio: Float
    
    init() {
        self.s1 = 1 / 1024
        self.s2 = 1 / 64
        
        self.logRatio = -log(s2/s1)
    }

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

final class StratifiedMutation: PrimarySpaceMutation {
    weak var sampler: Sampler!

    private var k: Float = 0
    private var t: Float = 1
    private var alpha: Float = 1
    private var beta: Float = 1
    private var targetAcceptance: Float = 0.5
    private var b: Float = 1

    private let lambda: Float = 10
    private let sMin: Float = 1 / 512
    private let sMax: Float = 1 / 16
    
    init() {
        self.targetAcceptance = 0.25
        self.b = 1
    }

    func setup(acceptance: Float, I: Float, targetAcceptance: Float, b: Float) {
        self.targetAcceptance = targetAcceptance
        self.b = b
        k += (lambda / t) * (targetAcceptance - acceptance)
        alpha = k * I / b
        beta = alpha / (exp(-alpha * sMin) - exp(-alpha * sMax))
        t += 1
    }
    
    func mutate(u: [PSSMLTSampler.PrimarySample], i: Int) -> Float {
        let value = u[i].value
        let rand = sampler.gen()
        let s = log(exp(-alpha * sMin) - ((alpha * rand) / beta))
        
        return (value + s).modulo(1.0)
    }
}

final class MalaMutation: PrimarySpaceMutation {
    weak var sampler: Sampler!

    private var gradients: [Float] = [0, 0]
    private var rng2: Vec2? = nil
    private var step: Float = 0.1
    
    private var fallback: PrimarySpaceMutation = KelemenMutation()
    
    func setup(step: Float, gradient: Vec2) {
        self.fallback.sampler = sampler
        self.step = step
        self.gradients = [gradient.x, gradient.y]
        self.rng2 = nil
    }

    func mutate(value: Float) -> Float {
        return 0
    }
    
    func mutate(u: [PSSMLTSampler.PrimarySample], i: Int) -> Float {
        guard let gradient = gradients[safe: i] else { return fallback.mutate(u: u, i: i) }

        let mean = u[i].value + 0.5 * step * gradient
        rng2 = rng2 ?? gaussian(sigma: step)
        let w = rng2?[i] ?? 0
        var result = mean + step.sqrt() * w
        // Maybe check for bounds in x-y here and bounce back
        result -= floor(result)
        return result
    }
    
    /// Returns a 2D sample proportional to a gausian distribution with `mean=0` and `sigma` standard deviation.
    private func gaussian(sigma: Float) -> Vec2 {
        var u1: Float
        // Perhaps add epsilon instead of repeat
        repeat {
            u1 = Float.random(in: 0 ... 1)
        } while (u1 == 0)
        let u2 = Float.random(in: 0 ... 1)

        let mag = sigma * (-2 * log(u1)).sqrt()
        
        let z0: Float  = mag * (2 * .pi * u2).cos();
        let z1: Float  = mag * (2 * .pi * u2).sin();
        
        return Vec2(z0, z1)
    }
}

final class MalaAdamMutation: PrimarySpaceMutation {
    /// Exponential decay rates
    struct Decay {
        let alpha: Float
        let beta: Float

        init(alpha: Float = 0.9, beta: Float = 0.999) {
            self.alpha = alpha
            self.beta = beta
        }
    }
    
    /// Diminishing adaptation exponents
    struct Adaptation {
        let c1: Float
        let c2: Float
    }

    var sampler: (any Sampler)!
    
    private var fallback: PrimarySpaceMutation = KelemenMutation()
    private var gradients: [Float] = [0, 0]
    private var rng2: Vec2? = nil
    private var step: Float = 0.1
    private var delta: Float = 0.001
    private var decay: Decay = Decay()
    private var adaptation: Adaptation = Adaptation(c1: 0.5, c2: 0.5)
    
    /// Accumulation matrix
    private var G = Vec2()
    /// Preconditioning matrix
    private var M = Vec2()
    /// Momentum
    private var m = Vec2()
    private var d = Vec2()
    private var t: Float = 1
    
    func setup(step: Float, delta: Float = 0.001, decay: Decay = Decay(), gradient: Vec2) {
        self.fallback.sampler = sampler
        self.step = step
        self.decay = decay
        self.gradients = [gradient.x, gradient.y]
        self.rng2 = nil
    }
    
    func mutate(u: [PSSMLTSampler.PrimarySample], i: Int) -> Float {
        // Only mutate x-y rng
        guard gradients[safe: i] != nil else { return fallback.mutate(u: u, i: i) }

        // Sample 2d normal distribution
        rng2 = rng2 ?? gaussian(sigma: 1)
        
        // Compute adam gradient descent once per u vector
        if i == 0 {
            G = accumulationMatrix(t: t + 1)
            M = preconditionMatrix(t: t + 1)
            m = momentum(t: t + 1)
            t += 1
        }

        let mean = u[i].value + 0.5 * step * M * m
        let w = rng2?[i] ?? 0
        var result = mean + step.sqrt() * M.squareRoot() * w
        
        // Maybe check for bounds in x-y here and bounce back
        result -= floor(result)
        return result[i]
    }
    
    // G(t)
    private func accumulationMatrix(t: Float) -> Vec2 {
        let (dx, dy) = (gradients[0], gradients[1])
        let g = Mat2(rows: [Vec2(dx, 0), Vec2(0, dy)])
        let diagonal = (g * g).diagonal
        return decay.beta * G + (1 - decay.beta) * diagonal
    }
    
    // M(t)
    private func preconditionMatrix(t: Float) -> Vec2 {
        let ones = Vec2(1, 1)
        return ones / ((delta * ones) + t.pow(-adaptation.c1) * G.squareRoot())
    }
    
    // m(t)
    private func momentum(t: Float) -> Vec2 {
        let (dx, dy) = (gradients[0], gradients[1])
        let g = Mat2(rows: [Vec2(dx, 0), Vec2(0, dy)])
        d = decay.alpha * d + (1 - decay.alpha) * g.diagonal
        return t.pow(-adaptation.c2) * d + g.diagonal
    }
    
    /// Returns a 2D sample proportional to a gausian distribution with `mean` and `sigma` standard deviation.
    private func gaussian(sigma: Float) -> Vec2 {
        var u1: Float
        // Perhaps add epsilon instead of repeat
        repeat {
            u1 = Float.random(in: 0 ... 1)
        } while (u1 == 0)
        let u2 = Float.random(in: 0 ... 1)

        let mag = sigma * (-2 * log(u1)).sqrt()
        
        let z0: Float  = mag * (2 * .pi * u2).cos();
        let z1: Float  = mag * (2 * .pi * u2).sin();
        
        return Vec2(z0, z1)
    }
}

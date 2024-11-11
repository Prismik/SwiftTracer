//
//  convergence.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-11-08.
//

import Foundation

/// Integrates a scene by keeping intermediate rendered images
final class ConvergenceIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        /// Number of steps, each of them rendering with 2^n samples, where n is the current step.
        case steps
        case integrator
        case strategy
    }
    
    var gradientDomain: Bool {
        return integrator as? GradientDomainIntegrator != nil
    }
    
    private(set) var steps: Int
    private(set) var times: [Int64] = []

    private let integrator: Integrator
    private let clock = ContinuousClock()
    private var renderTime: Duration = .zero
    private var accumulatedResult: GradientDomainResult
    
    init(integrator: Integrator, steps: Int) {
        self.integrator = integrator
        self.accumulatedResult = GradientDomainResult(primal: .empty, directLight: .empty, img: .empty, dx: .empty, dy: .empty)
        self.steps = steps
    }
    
    func preprocess(scene: Scene, sampler: any Sampler) {
        integrator.preprocess(scene: scene, sampler: sampler)
    }

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let sampler = sampler.new(nspp: 1)

        for iteration in 1 ... steps {
            print("Creating convergence image \(iteration)/\(steps) ...")
            
            let start = clock.now
            let newResult: GradientDomainResult
            if let gradientIntegrator = integrator as? GradientDomainIntegrator {
                newResult = gradientIntegrator.render(scene: scene, sampler: sampler)
            } else {
                let result = integrator.render(scene: scene, sampler: sampler)
                newResult = GradientDomainResult(primal: result, directLight: .empty, img: .empty, dx: .empty, dy: .empty)
            }
            
            if iteration == 1 {
                accumulatedResult = newResult
            } else {
                accumulatedResult.scale(by: Float(iteration))
                accumulatedResult.merge(with: newResult)
                accumulatedResult.scale(by: 1.0 / Float(iteration + 1))
            }

            registerTime(start: start, iteration: iteration)
            
            if let gradientIntegrator = integrator as? GradientDomainIntegrator {
                let recontsruction = gradientIntegrator.reconstruct(using: accumulatedResult)
                guard Image(encoding: .exr).write(img: recontsruction.img, to: "convergence-\(iteration).exr") else {
                    fatalError("Error in saving convergence image")
                }
            } else {
                guard Image(encoding: .exr).write(img: accumulatedResult.primal, to: "convergence-\(iteration).exr") else {
                    fatalError("Error in saving convergence image")
                }
            }
        }
        
        if let gradientIntegrator = integrator as? GradientDomainIntegrator {
            return gradientIntegrator.reconstruct(using: accumulatedResult).img
        } else {
            return accumulatedResult.primal
        }
    }
    
    private func registerTime(start: ContinuousClock.Instant, iteration: Int) {
        let duration = start.duration(to: .now)
        renderTime += duration
        print("Convergence image \(iteration)/\(steps) rendered in \(duration.components.seconds) seconds")
        times.append(renderTime.components.seconds)
    }
}

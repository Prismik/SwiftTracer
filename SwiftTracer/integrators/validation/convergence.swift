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
        /// Maximum rendering time ine seconds, after which the rendering will end even if target `steps` was not reached.
        case timeout
        case integrator
        case strategy
    }
    
    let identifier = "convergence"
    
    var gradientDomain: Bool {
        return integrator as? GradientDomainIntegrator != nil
    }
    
    /// Timeout in seconds
    private(set) var timeout: Duration
    private(set) var times: [Int64] = []

    private let integrator: Integrator
    private let clock = ContinuousClock()
    private var renderTime: Duration = .zero
    private var accumulatedResult: GradientDomainResult
    
    init(integrator: Integrator, timeout: Int) {
        self.integrator = integrator
        self.accumulatedResult = GradientDomainResult(primal: .empty, directLight: .empty, img: .empty, dx: .empty, dy: .empty)
        self.timeout = Duration.seconds(timeout)
    }
    
    func preprocess(scene: Scene, sampler: any Sampler) {
        integrator.preprocess(scene: scene, sampler: sampler)
    }

    func render(scene: Scene, sampler: any Sampler) -> PixelBuffer {
        let sampler = sampler.new(nspp: 1)

        for iteration in 1 ... Int.max {
            print("Creating convergence image \(iteration) ...")
            
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
                guard Image(encoding: .exr).write(img: recontsruction.img, to: "\(integrator.identifier)_\(iteration).exr") else {
                    fatalError("Error in saving convergence image")
                }
            } else {
                guard Image(encoding: .exr).write(img: accumulatedResult.primal, to: "\(integrator.identifier)_\(iteration).exr") else {
                    fatalError("Error in saving convergence image")
                }
            }
            
            guard renderTime < timeout else { break }
        }
        
        dumpTimesToCsv()
        
        if let gradientIntegrator = integrator as? GradientDomainIntegrator {
            return gradientIntegrator.reconstruct(using: accumulatedResult).img
        } else {
            return accumulatedResult.primal
        }
    }
    
    private func registerTime(start: ContinuousClock.Instant, iteration: Int) {
        let duration = start.duration(to: .now)
        renderTime += duration
        print("Convergence image \(iteration) rendered in \(duration.components.seconds) seconds")
        times.append(renderTime.components.seconds)
    }
    
    private func dumpTimesToCsv() {
        let fileManager = FileManager.default
        var csvString = times.reduce(into: "") { acc, time in
            acc += "\(time)\n"
        }
        csvString.removeLast()

        do {
            let path = try fileManager.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: false)
            let filename = path.appendingPathComponent("_time.csv")
            try csvString.write(to: filename, atomically: true, encoding: .utf8)
        } catch {
            print("error creating file")
        }
    }
}

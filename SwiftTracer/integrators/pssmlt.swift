//
//  pssmlt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-09-10.
//

import Foundation
import Progress

final class PssmltIntegrator: Integrator {
    internal struct StateMCMC {
        var pos: Vec2
        var contrib: Color
        var weight: Float = 0
        var targetFunction: Float = 0
        
        init(contrib: Color, pos: Vec2) {
            self.contrib = contrib
            self.pos = pos
            self.targetFunction = (contrib.x + contrib.y + contrib.z) / 3
        }
    }
    
    internal struct SampleMCMC {
        let x: Int
        let y: Int
        var contrib: Color
    }

    // TODO Find appropriate block structure
    private struct MarkovChain {
        private(set) var samples: [SampleMCMC] = []

        mutating func add(state: inout StateMCMC) {
            let w = state.weight / state.targetFunction
            let sample = SampleMCMC(x: Int(state.pos.x), y: Int(state.pos.y), contrib: state.contrib * w)
            samples.append(sample)
            state.weight = 0
        }
    }

    /// TODO Allow to plug and play this thing
    private let integrator: PathIntegrator = PathIntegrator(maxDepth: 16)

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let image = Array2d(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: Color())
        guard let sampler = sampler as? PSSMLTSampler else { return image }
        
        let b = self.b(scene: scene, sampler: sampler)
        let totalSamples = sampler.nbSamples * Int(scene.camera.resolution.x) * Int(scene.camera.resolution.y)
        let nbSamplesPerChain = 100_000
        let nbChains = totalSamples / nbSamplesPerChain
        
        // Run chains in parallel
        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: nbChains, printer: Printer())
            let chains = await chains(samples: totalSamples, nbChains: nbChains, integrator: integrator, scene: scene, sampler: sampler) {
                progress.next()
            }
            return assemble(chains: chains, image: image)
        }
        gcd.wait()
        
        // TODO Normalize?
        
        let average = image.reduce(Color()) { acc, pixel in
            return acc + pixel
        } / Float(image.size)
        let averageLuminance = (average.x + average.y + average.z) / 3.0
        
        print("Large steps taken => \(sampler.nbLargeSteps)")
        print("Small steps taken => \(sampler.nbSmallSteps)")
        // Scaling is useless for now; most of the image is black
        // image.scale(by: b / averageLuminance)
        return image
    }
    
    /// Computes the normalization factor
    private func b(scene: Scene, sampler: PSSMLTSampler) -> Float {
        let nb = 100000
        let b = (0 ..< nb).map { _ in
            let state = sample(scene: scene, sampler: sampler)
            return state.targetFunction
        }.reduce(0, +) / Float(nb)
        
        return b
    }
    
    private func sample(scene: Scene, sampler: PSSMLTSampler) -> StateMCMC {
        let rng2 = sampler.next2()
        let x = Int(scene.camera.resolution.x * rng2.x)
        let y = Int(scene.camera.resolution.y * rng2.y)
        let contrib = integrator.render(pixel: (x, y), scene: scene, sampler: sampler)
        return StateMCMC(contrib: contrib, pos: Vec2(Float(x), Float(y)))
    }

    private func chains(samples: Int, nbChains: Int, integrator: PathIntegrator, scene: Scene, sampler: PSSMLTSampler, increment: @escaping () -> Void) async -> [MarkovChain] {
        let nbSamplesPerChain = 100_000
        return await withTaskGroup(of: MarkovChain.self) { group in
            for _ in 0 ..< nbChains {
                group.addTask {
                    increment()
                    return self.renderChain(samples: nbSamplesPerChain, scene: scene, sampler: sampler)
                }
            }

            var chains: [MarkovChain] = []
            for await chain in group {
                chains.append(chain)
            }
            
            return chains
        }
    }
    
    private func renderChain(samples: Int, scene: Scene, sampler: PSSMLTSampler) -> MarkovChain {
        let sampler = sampler.clone()
        var chain = MarkovChain()
        sampler.step = .large
        
        var state = self.sample(scene: scene, sampler: sampler)
        sampler.accept()
        
        for _ in 0 ..< samples {
            sampler.step = sampler.gen() < sampler.largeStepRatio
            ? .large
            : .small
            
            var proposedState = self.sample(scene: scene, sampler: sampler)
            let acceptProbability = min(
                1.0,
                proposedState.targetFunction / state.targetFunction
            )
            
            // This is veach style expectations; See if using Kelemen style wouldn't be more appropriate
            state.weight += 1 - acceptProbability
            proposedState.weight += acceptProbability
            
            if acceptProbability > sampler.gen() {
                chain.add(state: &state)
                //image.add(state: &state)
                sampler.accept()
                state = proposedState
            } else {
                chain.add(state: &proposedState)
                //image.add(state: &proposedState)
                sampler.reject()
            }
        }
        
        // Flush the last state
        chain.add(state: &state)
        //image.add(state: &state)
        
        return chain
    }
    
    private func assemble(chains: [MarkovChain], image: Array2d<Color>) -> Array2d<Color> {
        for chain in chains {
            for sample in chain.samples {
                image.add(sample)
            }
        }

        return image
    }
}

private extension Array2d<Color> {
    func add(_ state: PssmltIntegrator.SampleMCMC) {
        add(value: state.contrib, state.x, state.y)
    }
    
    // TODO Move into Array2d by fixing generic constraints
    func scale(by factor: Float) {
        for (i, item) in self.enumerated() {
            let (x, y) = index2d(i)
            set(value: item * factor, x, y)
        }
    }
}

//
//  pssmlt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-09-10.
//

import Foundation
import Progress

final class PssmltIntegrator: Integrator {
    struct SampleMCMC {
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
    
    // TODO Find appropriate block structure
    private struct MarkovChain {
    }

    /// TODO Allow to plug and play this thing
    private let integrator: PathIntegrator = PathIntegrator(maxDepth: 16)

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let image = Array2d(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: Color())
        guard let sampler = sampler as? PSSMLTSampler else { return image }
        
        let b = self.b(scene: scene, sampler: sampler)
        // TODO These values are incorrect right now because we simply run one chain
        let totalSamples = sampler.nbSamples * Int(scene.camera.resolution.x) * Int(scene.camera.resolution.y)
        let nbSamplesPerChain = 100_000
        let nbChains = totalSamples / nbSamplesPerChain
        
        var samplers: [PSSMLTSampler] = []
        for _ in 0 ..< nbChains {
            samplers.append(sampler.clone())
        }

        // Run chains in parallel
        for s in samplers {
            
        }

        sampler.step = .large
        
        var state = sample(scene: scene, sampler: sampler)
        sampler.accept()
        
        var progress = ProgressBar(count: totalSamples, printer: Printer())
        for _ in 0 ..< totalSamples {
            sampler.step = sampler.gen() < sampler.largeStepRatio
                ? .large
                : .small
            
            var proposedState = sample(scene: scene, sampler: sampler)
            let acceptProbability = min(
                1.0,
                proposedState.targetFunction / state.targetFunction
            )
            
            // This is veach style expectations; See if using Kelemen style wouldn't be more appropriate
            state.weight += 1 - acceptProbability
            proposedState.weight += acceptProbability
            
            if acceptProbability > sampler.gen() {
                image.add(state: &state)
                sampler.accept()
                state = proposedState
            } else {
                image.add(state: &proposedState)
                sampler.reject()
            }
            
            progress.next()
        }

        // Flush the last state
        image.add(state: &state)
        sampler.reset()
        
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
    
    private func sample(scene: Scene, sampler: PSSMLTSampler) -> SampleMCMC {
        let rng2 = sampler.next2()
        let x = Int(scene.camera.resolution.x * rng2.x)
        let y = Int(scene.camera.resolution.y * rng2.y)
        let contrib = integrator.render(pixel: (x, y), scene: scene, sampler: sampler)
        return SampleMCMC(contrib: contrib, pos: Vec2(Float(x), Float(y)))
    }
    
    /// Computes the normalization factor
    private func b(scene: Scene, sampler: PSSMLTSampler) -> Float {
        let nb = 100000
        let b = (0 ..< nb).map { _ in
            let state = self.sample(scene: scene, sampler: sampler)
            return state.targetFunction
        }.reduce(0, +) / Float(nb)
        
        return b
    }
    
    private func chains(samples: Int, scene: Scene, samplers: [PSSMLTSampler], increment: @escaping () -> Void) async -> [MarkovChain] {
        // TODO MOVE THAT OUTSIDE
        let image = Array2d(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: Color())
        return await withTaskGroup(of: MarkovChain.self) { group in
            for sampler in samplers {
                group.addTask {
                    let chain = MarkovChain()
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
                            image.add(state: &state)
                            sampler.accept()
                            state = proposedState
                        } else {
                            image.add(state: &proposedState)
                            sampler.reject()
                        }
                        
                        increment()
                    }
                    
                    // Flush the last state
                    image.add(state: &state)
                    sampler.reset()
                    
                    return chain
                }
            }

            var chains: [MarkovChain] = []
            for await chain in group {
                chains.append(chain)
            }
            
            return chains
        }
    }
}

private extension Array2d<Color> {
    func add(state: inout PssmltIntegrator.SampleMCMC) {
        let w = state.weight / state.targetFunction
        add(value: state.contrib * w, Int(state.pos.x), Int(state.pos.y))
        state.weight = 0
    }
    
    // TODO Move into Array2d by fixing generic constraints
    func scale(by factor: Float) {
        for (i, item) in self.enumerated() {
            let (x, y) = index2d(i)
            set(value: item * factor, x, y)
        }
    }
}

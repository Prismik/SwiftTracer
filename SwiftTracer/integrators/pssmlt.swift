//
//  pssmlt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-09-10.
//

import Foundation

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

    /// TODO Allow to plug and play this thing
    private let integrator: PathIntegrator = PathIntegrator(maxDepth: 16)

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let image = Array2d(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: Color())
        guard let sampler = sampler as? PSSMLTSampler else { return image }
        
        let totalSamples = sampler.nbSamples * Int(scene.camera.resolution.x) * Int(scene.camera.resolution.y)
        let nbSamplesPerChain = 100000
        let nbChains = totalSamples / nbSamplesPerChain
        
        sampler.step = .large
        
        var state = sample(scene: scene, sampler: sampler)
        sampler.accept()
        
        for _ in 0 ..< nbSamplesPerChain {
            sampler.step = sampler.next() < sampler.largeStepRatio
                ? .large
                : .small
            
            var proposedState = sample(scene: scene, sampler: sampler)
            let acceptProbability = min(
                1.0,
                proposedState.targetFunction / state.targetFunction
            )
            state.weight += 1 - acceptProbability
            proposedState.weight += acceptProbability
            
            if acceptProbability > sampler.gen() {
                image.add(state: state)
                sampler.accept()
                state = proposedState
            } else {
                image.add(state: proposedState)
                sampler.reject()
            }
        }

        // Flush the last state
        image.add(state: state)
        sampler.reset()
        return image
    }
    
    private func sample(scene: Scene, sampler: PSSMLTSampler) -> SampleMCMC {
        let rng2 = sampler.next2()
        let x = Int(scene.camera.resolution.x * rng2.x)
        let y = Int(scene.camera.resolution.y * rng2.y)
        let contrib = integrator.render(pixel: (x, y), scene: scene, sampler: sampler)
        return SampleMCMC(contrib: contrib, pos: Vec2(Float(x), Float(y)))
    }
}

private extension Array2d<Color> {
    func add(state: PssmltIntegrator.SampleMCMC) {
        add(value: state.contrib * state.weight, Int(state.pos.x), Int(state.pos.y))
    }
}
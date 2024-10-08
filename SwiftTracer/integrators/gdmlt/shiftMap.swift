//
//  shiftMap.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

// TODO Allow for plug and play of other types of integrators
struct ShiftMapParams {
    let seed: UInt64?
    
    init(seed: UInt64? = nil) {
        self.seed = seed
    }
}

protocol ShiftMapping {
    var sampler: Sampler { get set }

    func shift(
        pixel: Vec2,
        offset: Vec2,
        params: ShiftMapParams
    ) -> Color
}

final class RandomSequenceReplay: ShiftMapping {
    var sampler: Sampler
    
    private let integrator: PathIntegrator
    private let scene: Scene

    init(integrator: PathIntegrator, scene: Scene, sampler: Sampler) {
        self.integrator = integrator
        self.scene = scene
        self.sampler = sampler
    }

    func shift(
        pixel: Vec2,
        offset: Vec2,
        params: ShiftMapParams
    ) -> Color {
        guard let seed = params.seed else { fatalError("Wrong params provided to \(String(describing: self))") }
        let pixel = pixel + offset
        guard pixel.x > 0, pixel.y > 0, pixel.x < scene.camera.resolution.x - 1, pixel.y < scene.camera.resolution.y - 1 else { return .zero }
        sampler.rng.state = seed
        return integrator.render(pixel: pixel, scene: scene, sampler: sampler)
    }
}

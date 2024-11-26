//
//  timeboxed.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-11-02.
//

import Foundation

final class TimeboxedIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        /// In seconds
        case time
        case integrator
    }
    
    let identifier = "timeboxed"
    
    var gradientDomain: Bool {
        return integrator as? GradientDomainIntegrator != nil
    }

    private let integrator: Integrator
    private let maxDuration: Duration

    init(integrator: Integrator, time: Int) {
        self.integrator = integrator
        self.maxDuration = .seconds(time)
    }

    func render(scene: Scene, sampler: Sampler) -> PixelBuffer {
        let clock = ContinuousClock()
        let start = clock.now
        var renderTime: Duration = .zero
        var iterations = 1
        var img = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
        while true {
            let result = integrator.render(scene: scene, sampler: sampler)
            img += result
            
            renderTime = start.duration(to: .now)
            guard renderTime <= maxDuration else { break }

            print("Rendering time left ... starting again")
            iterations += 1
        }
    
        img.scale(by: 1 / Float(iterations))

        print("Iterations => \(iterations)")
        print("nspp => \(iterations * scene.sampler.nbSamples)")
        return img
    }
    
    func render(scene: Scene, sampler: Sampler) -> GradientDomainResult {
        guard let integrator = integrator as? GradientDomainIntegrator else {
            fatalError("Trying to render in the gradient domain using a non gradient domain integrator")
        }
    
        let clock = ContinuousClock()
        let start = clock.now
        var renderTime: Duration = .zero
        var iterations = 1
        var img = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
        var primal = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
        var dx = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
        var dy = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
        var directLight = PixelBuffer(width: Int(scene.camera.resolution.x), height: Int(scene.camera.resolution.y), value: .zero)
        while true {
            let result: GradientDomainResult = integrator.render(scene: scene, sampler: sampler)
            img += result.img
            primal += result.primal
            dx += result.dx
            dy += result.dy
            directLight += result.directLight
            
            renderTime = start.duration(to: .now)
            guard renderTime <= maxDuration else { break }

            print("Rendering time left ... starting again")
            iterations += 1
        }
        
        primal.scale(by: 1 / Float(iterations))
        img.scale(by: 1 / Float(iterations))
        dx.scale(by: 1 / Float(iterations))
        dy.scale(by: 1 / Float(iterations))

        print("Iterations => \(iterations)")
        print("nspp => \(iterations * scene.sampler.nbSamples)")
        
        let intermediate = GradientDomainResult(primal: primal, directLight: directLight, img: img, dx: dx, dy: dy)
        return integrator.reconstruct(using: intermediate)
    }
}

extension TimeboxedIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: Sampler) {
        
    }
    
    func li(ray: Ray, scene: Scene, sampler: Sampler) -> Color {
        return .zero
    }
    
    func li(pixel: Vec2, scene: Scene, sampler: Sampler) -> Color {
        return .zero
    }
}

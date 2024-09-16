//
//  pssmlt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-09-10.
//

import Foundation

final class PssmltIntegrator: Integrator {
    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let image = Array2d(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: Color())
        
        for x in 0 ..< Int(scene.camera.resolution.x) {
            for y in 0 ..< Int(scene.camera.resolution.y) {
                // Get contribution ????????
            }
        }
    
        return image
    }
}

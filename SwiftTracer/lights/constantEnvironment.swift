//
//  constantEnvironment.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-28.
//

import Foundation

final class ConstantEnvironmentLight: Light {
    var category: LightCategory = .delta(type: .direction)
    let transform: Transform
    let I: Color

    private var sceneRadius: Float = 0
    private var sceneCenter: Point3 = .zero

    init(transform: Transform, intensity: Color) {
        self.transform = transform
        self.I = intensity
    }

    func preprocess(scene: Scene) {
        let (center, radius) = scene.bounds
        self.sceneRadius = radius
        self.sceneCenter = center
    }
    
    func sampleLi(context: LightSample.Context, sample: Vec2) -> LightSample? {
        // Light is always incident with the same angle of z = 1
        // Any point at 2*radius will 100% of the time be outside the scene. If visible, then the point receives light.
        let outsidePoint = context.p + transform.vector(Vec3.unit(.z)).normalized() * 2 * sceneRadius
        let wi = (outsidePoint - context.p).normalized()
        return LightSample(L: I, wi: wi, p: outsidePoint, n: .zero, pdf: 1)
    }
    
    // Approximation of the power by the area of the circle that bounds the sphere
    func phi() -> Color {
        return I * .pi * sceneRadius.pow(2)
    }
    
    func pdfLi(context: LightSample.Context, y: Point3) -> Float {
        return 0
    }
}

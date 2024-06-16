//
//  point.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-13.
//

import Foundation

final class PointLight: Light {
    let category: LightCategory = .delta(type: .position)
    let transform: Transform
    let I: Color

    init(transform: Transform, intensity: Color) {
        self.transform = transform
        self.I = intensity
    }

    func preprocess() {
        
    }

    func sampleLi(context: LightSample.Context, sample: Vec2) -> LightSample? {
        let p = transform.point(Point3())
        let sqDistance = p.distance2(context.p)
        let wi = (p - context.p).normalized()
        let li = I / sqDistance
        return LightSample(L: li, wi: wi, p: p, pdf: 1)
    }
    
    func phi() -> Color {
        return 4 * .pi * I
    }

    func pdfLi(context: LightSample.Context, y: Point3) -> Float {
        return 0
    }
    
    func L(p: Point3, n: Vec3, uv: Vec2, wo w: Vec3) -> Color {
        return Color()
    }
}

//
//  spot.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-17.
//

import Foundation

final class SpotLight: Light {
    let category: LightCategory = .delta(type: .position)
    let transform: Transform
    let intensity: Color
    let cosFalloffStart: Float
    let cosFalloffEnd: Float
    
    init(transform: Transform, intensity: Color, start: Float, end: Float) {
        self.transform = transform
        self.intensity = intensity
        self.cosFalloffStart = start.toRadians().cos()
        self.cosFalloffEnd = end.toRadians().cos()
    }

    func preprocess(scene: Scene) {
        
    }

    func sampleLi(context: LightSample.Context, sample: Vec2) -> LightSample? {
        let p = transform.point(Point3())
        let sqDistance = p.distance2(context.p)
        let wi = (p - context.p).normalized()
        let n = transform.normal(Vec3.unit(.z)).normalized()
        let frame = Frame(n: n)
        let wo = frame.toLocal(v: -wi).normalized()
        let li = I(wo: wo) / sqDistance
        guard li.length != 0 else { return nil }
        return LightSample(L: li, wi: wi, p: p, n: n, pdf: 1)
    }
    
    func phi() -> Color {
        let delta = cosFalloffStart - cosFalloffEnd
        return 2 * .pi * intensity * ((1 - cosFalloffStart) + delta / 2)
    }

    func pdfLi(context: LightSample.Context, y: Point3) -> Float {
        return 0
    }
    
    private func I(wo: Vec3) -> Color {
        return smoothFalloff(x: wo.z, a: cosFalloffEnd, b: cosFalloffStart) * intensity
    }
    
    /// Smooth interpolation of a value in the range of falloff(start ... end)
    /// > Note: The return value depends on where the point is positioned.
    /// > - **1** if within total illumination.
    /// > - **0** if outside of both partial illumination and total illumination.
    /// > - **Cubic polynomial interpolation** if within partial illumination.
    private func smoothFalloff(x: Float, a: Float, b: Float) -> Float {
        guard a != b else { return x < a ? 0 : 1 }
        let t = ((x - a) / (b - a)).clamped(0, 1)
        return t * t * (3 - 2 * t)
    }
}

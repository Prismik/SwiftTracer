//
//  blend.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-05.
//

import Foundation

/// Material with a linear combination of two different materials.
/// Any of the other materials can be combined into a `Blend` instance by using the alpha value.
final class Blend: Material {
    /// The first material part of the blending process.
    private let m1: Material
    /// The second material part of the blending process.
    private let m2: Material
    /// Alpha value for blending in between m1 and m2.
    private let alpha: Texture
    
    init(m1: Material, m2: Material, alpha: Texture) {
        self.m1 = m1
        self.m2 = m2
        self.alpha = alpha
    }

    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection? {
        guard wo.z >= 0 else { return nil }
        
        let a: Float = self.alpha.get(uv: uv, p: p)
        var rng = sample
        rng.x = sample.x < a
            ? sample.x / a
            : (sample.x - a) / (1 - a)
        
        let material = sample.x < a
            ? m1
            : m2
        return material.sample(wo: wo, uv: uv, p: p, sample: rng)
    }
    
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color {
        guard !hasDelta(uv: uv, p: p) else { return Color() }
        
        let a: Float = self.alpha.get(uv: uv, p: p)
        return a * m1.evaluate(wo: wo, wi: wi, uv: uv, p: p)
            + (1 - a) * m2.evaluate(wo: wo, wi: wi, uv: uv, p: p)
    }
    
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float {
        guard !hasDelta(uv: uv, p: p) else { return 0 }
        
        let a: Float = self.alpha.get(uv: uv, p: p)
        return a * m1.pdf(wo: wo, wi: wi, uv: uv, p: p)
            + (1 - a) * m2.pdf(wo: wo, wi: wi, uv: uv, p: p)
    }
    
    func hasDelta(uv: Vec2, p: Point3) -> Bool {
        return m1.hasDelta(uv: uv, p: p) || m2.hasDelta(uv: uv, p: p)
    }
}

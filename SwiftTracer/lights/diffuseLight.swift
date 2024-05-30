//
//  diffuseLight.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-30.
//

import Foundation

// TODO Check how pbrt handles this and modify code accordingly
final class DiffuseLight: Material {
    let hasEmission = true
    let isMedia = false
    let density: Float = 0
    let texture: Texture<Color>
    
    init(texture: Texture<Color>) {
        self.texture = texture
    }

    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection? {
        return nil
    }
    
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color {
        return Color()
    }
    
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float {
        return 0
    }
    
    func hasDelta(uv: Vec2, p: Point3) -> Bool {
        return false
    }
    
    func emission(wo: Vec3, uv: Vec2, p: Point3) -> Color {
        guard wo.z > 0 else { return Color() }
        return texture.get(uv: uv, p: p)
    }
}

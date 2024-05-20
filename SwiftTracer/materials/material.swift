//
//  material.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import simd
import Foundation

struct SampledDirection {
    let weight: Color
    let wi: Vec3
}
protocol Material {
    func sample(wo: Vec3, uv: Vec2, p: Point3, sample: Vec2) -> SampledDirection?
    func evaluate(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Color
    func pdf(wo: Vec3, wi: Vec3, uv: Vec2, p: Point3) -> Float
    func hasDelta(uv: Vec2, p: Point3) -> Bool
    func emission(wo: Vec3, uv: Vec2, p: Point3) -> Color
    
    var hasEmission: Bool { get }
    var isMedia: Bool { get }
    var density: Float { get }
}

extension Material {
    static func from(json: Data) {
        
    }
}

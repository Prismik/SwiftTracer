//
//  environmentMap.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2025-01-06.
//

import Foundation

final class EnvironmentMapLight: Light {
    var category: LightCategory = .infinite
    let texture: Texture
    let transform: Transform

    let distribution: DistributionTwoDimension
    
    private var sceneRadius: Float = 0
    private var sceneCenter: Point3 = .zero
    
    // Convenience
    private var pixelBuffer: PixelBuffer {
        guard case .textureMap(let values, _, _, _) = texture else {
            fatalError("Invalid texture type for environment map")
        }
        
        return values
    }

    init(transform: Transform, texture: Texture) {
        self.transform = transform
        self.texture = texture
        
        guard case .textureMap(let values, _, _, _) = texture else {
            fatalError("Invalid texture type for environment map")
        }
        
        let pdfBitmap = PixelBuffer(copy: values)
        for y in 0 ..< values.height {
            let sinTheta = ((Float(y) + 0.5) * .pi / Float(values.height)).sin()
            for x in 0 ..< values.width {
                pdfBitmap[x, y] *= sinTheta
            }
        }

        self.distribution = DistributionTwoDimension(texture: pdfBitmap)
    }
    
    func preprocess(scene: Scene) {
        let (center, radius) = scene.bounds
        self.sceneRadius = radius
        self.sceneCenter = center
    }
    
    func sampleLi(context: LightSample.Context, sample: Vec2) -> LightSample? {
        var uv = distribution.sampleContinuous(uv: sample)
        uv.x = uv.x.clamped(0, Float(pixelBuffer.width) - 1.0)
        uv.y = uv.y.clamped(0, Float(pixelBuffer.height) - 1.0)
        
        let baseValue: Color = texture.get(uv: uv, p: .zero)
        let basePdf = distribution.pdf(uv: uv)
        
        // TODO Optimize
        let sinPhi: Float = (2 * .pi / Float(pixelBuffer.width) * Float(uv.x)).sin()
        let cosPhi: Float = (2 * .pi / Float(pixelBuffer.width) * Float(uv.x)).cos()
        
        let sinTheta: Float = (.pi / Float(pixelBuffer.height) * Float(uv.y)).sin()
        let cosTheta: Float = (.pi / Float(pixelBuffer.height) * Float(uv.y)).cos()
        
        let d = Vec3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta)
        let value: Color, pdf: Float
        if sinTheta == 0 {
            value = .zero
            pdf = 0
        } else {
            value = baseValue
            pdf = basePdf / .pi.pow(2) * sinTheta
        }
        
        guard let t = intersect(r: Ray(origin: context.p, direction: transform.vector(d))) else { return nil }
        let p = context.p + d * t
        let n = transform.normal((sceneCenter - p).normalized())
        
        // value must be divided by pdf outside of this
        return LightSample(
            L: value,
            wi: d,
            p: p,
            n: n,
            pdf: pdf
        )
    }
    
    func pdfLi(context: LightSample.Context, y: Point3) -> Float {
        let wi = (y - context.p).normalized()
        let (phi, theta) = Utils.sphericalCoordinatesFrom(direction: transform.vector(wi))
        let pdf = distribution.pdf(uv: Vec2(
            phi * Float(pixelBuffer.width),
            theta * Float(pixelBuffer.height)
        ))
        
        let sinTheta = (theta * .pi).sin()
        guard sinTheta != 0 else { return 0 }
        
        return pdf / (2 * .pi.pow(2) * sinTheta)
    }
    
    func phi() -> Color {
        return Color(repeating: distribution.marginal.integral * sceneRadius * sceneRadius * .pi)
    }
    
    func Le(ray: Ray) -> Color {
        // Conversion between ray direction and coordinates centered at zero?
        let uv = coordinates(d: transform.vector(ray.d))
        
        return texture.get(uv: uv, p: .zero)
    }
    
    private func coordinates(d: Vec3) -> Vec2 {
        let p = atan2f(d.y, d.x)
        let x = (p < 0 ? p + 2 * .pi : p) / .pi * 0.5
        let y = d.z.clamped(-1, 1).acos() / .pi
        return Vec2(x, y)
    }

    private func intersect(r: Ray) -> Float? {
        let dp = sceneCenter - r.o
        let a = r.d.lengthSquared
        let b = 2 * dp.dot(r.d)
        let c = dp.lengthSquared - sceneRadius * sceneRadius
        guard let (t0, t1) = Utils.solve(a: a, b: b, c: c) else { return nil }
        
        if t0 < r.t.min {
            return t1 < r.t.max ? t1 : nil
        } else if t0 < r.t.max {
            return t0
        } else {
            return nil
        }
    }
}

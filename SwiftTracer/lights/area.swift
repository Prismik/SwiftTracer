//
//  diffuseLight.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-30.
//

import Foundation

final class AreaLight: Light {
    let category: LightCategory = .area
    unowned var shape: Shape!
    let texture: Texture
    init(texture: Texture) {
        self.texture = texture
    }

    func preprocess(scene: Scene) {
        
    }
    
    func sampleLi(context: LightSample.Context, sample: Vec2) -> LightSample? {
        let es = shape.sampleDirect(p: context.p, sample: sample)
        guard !es.pdf.isZero && !(es.y - context.p).lengthSquared.isZero else { return nil }
        let wi = (es.y - context.p).normalized()
        let frame = Frame(n: es.n)
        let wo = frame.toLocal(v: -wi).normalized()
        let Le = L(p: es.y, n: es.n, uv: es.uv, wo: wo)
        return LightSample(L: Le, wi: wi, p: es.y, pdf: es.pdf)
    }
    
    func pdfLi(context: LightSample.Context, y: Point3) -> Float {
        return shape.pdfDirect(shape: shape, p: context.p, y: y, n: context.n)
    }
    
    func phi() -> Color {
        let L: Color
        switch texture {
        case .constant(let value):
            L = value
        case let .checkerboard2d(color1, color2, _, _):
            L = (color1 + color2) / 2
        case .textureMap(let values, _, _, _):
            L = values.reduce(Color(), { acc, rgb in
                return acc + rgb
            }) / Float(values.size)
        }
        
        return .pi * shape.area * L
    }
    
    func L(p: Point3, n: Vec3, uv: Vec2, wo: Vec3) -> Color {
        guard wo.z > 0 else { return Color() }
        return texture.get(uv: uv, p: p)
    }
}

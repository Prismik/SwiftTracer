//
//  environmentMap.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2025-01-06.
//

import Foundation

final class EnvironmentMapLight: Light {
    var category: LightCategory = .delta(type: .direction)
    let bitmap: PixelBuffer
    let transform: Transform
//    let distribution: DistributionTwoDimension
    private var sceneRadius: Float = 0
    private var sceneCenter: Point3 = .zero

    init(transform: Transform, bitmap: PixelBuffer) {
        self.transform = transform
        self.bitmap = bitmap
        
        
        // TODO PBRT uses scaled-valued image from the environment map. Check wtf is up with that.
        
//        self.distribution = DistributionTwoDimension(texture: texture)
    }
    
    func preprocess(scene: Scene) {
        let (center, radius) = scene.bounds
        self.sceneRadius = radius
        self.sceneCenter = center
    }
    
    func sampleLi(context: LightSample.Context, sample: Vec2) -> LightSample? {
        return nil
    }
    
    func pdfLi(context: LightSample.Context, y: Point3) -> Float {
        return 0
    }
    
    func phi() -> Color {
        return .zero
    }
    
    func Le(ray: Ray) -> Color {
        // TODO Figure out if this transformation makes sense
        // PBRT uses w = normalize(worldToLight(ray.d))
        let w = transform.vector(ray.d).normalized()
        let coords = Utils.sphericalCoordinatesFrom(direction: w)
        
        // TODO Figure out how to use st as in PBRT
        /*
         Point2f st(SphericalPhi(w) * Inv2Pi, SphericalTheta(w) * InvPi);
         return Spectrum(Lmap->Lookup(st), SpectrumType::Illuminant);
         */
        return .zero
    }
}

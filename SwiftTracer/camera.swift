//
//  camera.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-22.
//

import Foundation

final class Camera {
    let resolution: Vec2
    let transform: Transform
    let focalDistance: Float
    
    private let origin: Point3
    private let firstPixel: Point3
    private let du: Vec3
    private let dv: Vec3
    
    init(
        transform: Transform,
        firstPixel: Point3,
        du: Vec3,
        dv: Vec3,
        resolution: Vec2 = Vec2(512, 512),
        focalDistance: Float = 1,
        origin: Point3 = Point3()
    ) {
        self.resolution = resolution
        self.transform = transform
        self.focalDistance = focalDistance
        self.du = du
        self.dv = dv
        self.origin = origin
        self.firstPixel = firstPixel
        
    }

    func createRay(from positionInImage: Vec2) -> Ray {
        let pixelCenter = self.firstPixel + positionInImage.x * self.du + positionInImage.y * self.dv
        let direction = pixelCenter - self.origin
        return Ray(origin: self.origin, direction: direction)
    }
}

extension Camera: Decodable {
    convenience init(from decoder: Decoder) throws {
        
        self.init(transform: Transform(m: Mat4.identity()), firstPixel: Point3(), du: Vec3(), dv: Vec3())
    }
}

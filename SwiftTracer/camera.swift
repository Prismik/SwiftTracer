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
        t: Transform,
        firstPixel: Point3,
        du: Vec3,
        dv: Vec3,
        resolution: Vec2,
        focalDistance: Float,
        origin: Point3
    ) {
        self.resolution = resolution
        self.transform = t
        self.focalDistance = focalDistance
        self.du = du
        self.dv = dv
        self.origin = origin
        self.firstPixel = firstPixel
        
    }

    func createRay(from positionInImage: Vec2) -> Ray {
        let pixelCenter = firstPixel + positionInImage.x * du + positionInImage.y * dv
        let direction = pixelCenter - origin
        return Ray(origin: origin, direction: direction)
    }
}

extension Camera: Decodable {
    enum CodingKeys: String, CodingKey {
        case transform
        case fov
        case fdist
        case aperture
        case resolution
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let transform = try container.decode(Transform.self, forKey: .transform)
        let fov = try container.decodeIfPresent(Float.self, forKey: .fov) ?? 90
        let resolution = try container.decodeIfPresent(Vec2.self, forKey: .resolution) ?? Vec2(512, 512)
        let _ = try (container.decodeIfPresent(Float.self, forKey: .aperture) ?? 0) / 2.0
        let focalDistance = try container.decodeIfPresent(Float.self, forKey: .fdist) ?? 1.0
        
        let aspectRatio = resolution.x / resolution.y
        let viewportHeight = 2 * tan(fov.toRadians() / 2) * focalDistance
        let viewportWidth = aspectRatio * viewportHeight
        let origin = transform.point(Point3())
        let horizontal = transform.vector(Vec3(viewportWidth, 0, 0))
        let vertical = transform.vector(Vec3(0, -viewportHeight, 0))
        let firstPixel = origin
            - transform.vector(Vec3(0, 0, focalDistance))
            - horizontal / 2
            - vertical / 2

        self.init(
            t: transform,
            firstPixel: firstPixel,
            du: horizontal / resolution.x,
            dv: vertical / resolution.y,
            resolution: resolution,
            focalDistance: focalDistance,
            origin: origin
        )
    }
}

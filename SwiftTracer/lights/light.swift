//
//  light.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-13.
//

import Foundation

struct LightSample {
    struct Context {
        let p: Point3
        /// Surface normal
        let n: Vec3
        /// Shading normal
        let ns: Vec3
    }

    /// Radiance
    let L: Color
    /// Incident direction towards a point
    let wi: Vec3
    let pdf: Float
}

enum LightCategory: Decodable {
    enum CodingKeys: String, CodingKey {
        case category
        case delta
    }

    enum DeltaType: String {
        /// Emits from a single point in space
        case position
        /// Emits radiance along a single direction
        case direction
    }

    /// Lights described by a dirac distribution
    case delta(type: DeltaType)
    /// Emits radiance from the surface of a geometric shape
    case area
    /// No geometry associated, but provide radiance to rays that escape the scene
    case infinite
    
    var isDelta: Bool {
        switch self {
        case .delta: 
            return true
        default: 
            return false
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let category = try container.decode(String.self, forKey: .category)
        switch category {
        case "delta":
            let rawDelta = try container.decode(String.self, forKey: .delta)
            guard let delta = DeltaType(rawValue: rawDelta) else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: [CodingKeys.delta],
                        debugDescription: "Invalid delta type for light category"
                    )
                )
            }
            self = .delta(type: delta)
        case "area":
            self = .area
        case "infinite":
            self = .infinite
        default:
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [CodingKeys.category],
                    debugDescription: "Invalid light category"
                )
            )
        }
    }
}

struct AnyLight: Decodable {
    let category: LightCategory
    private(set) var wrapped: Light
    
    enum CodingKeys: String, CodingKey {
        case category
        
        // Point light
        case transform
        case intensity
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lightCategory = try container.decode(LightCategory.self, forKey: .category)
        self.category = lightCategory
        switch category {
        case .delta(type: .position):
            let transform = try container.decode(Transform.self, forKey: .transform)
            let intensity = try container.decode(Color.self, forKey: .intensity)
            self.wrapped = Point(transform: transform, intensity: intensity)
        default:
            fatalError() // Not implemented
        }
    }
}

protocol Light {
    var category: LightCategory { get }
    func preprocess()
    func sampleLi(context: LightSample.Context, sample: Vec2) -> LightSample?
    func pdfLi(context: LightSample.Context, wi: Vec3) -> Float
    func phi() -> Color
    func L(p: Point3, n: Vec3, uv: Vec2, w: Vec3) -> Color
    func Le(ray: Ray) -> Color
}

extension Light {
    /// Radiance contribution at a given point
    func L(p: Point3, n: Vec3, uv: Vec2, w: Vec3) -> Color {
        return Color()
    }
    
    /// Radiance contribution for infinite lights
    func Le(ray: Ray) -> Color {
        return Color()
    }
}

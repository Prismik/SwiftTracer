//
//  light.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-13.
//

import Foundation
import simd

public struct LightSample {
    public struct Context {
        /// Incoming point
        let p: Point3
        /// Surface normal
        let n: Vec3
        /// Shading normal
        let ns: Vec3
    }

    /// Radiance
    let L: Color
    /// Incident direction towards the light in world coordinates
    let wi: Vec3
    /// Point on the light source
    let p: Point3
    let pdf: Float
}

public enum LightCategory: Decodable {
    enum CodingKeys: String, CodingKey {
        case category
        case delta
    }

    public enum DeltaType: String {
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

    public init(from decoder: any Decoder) throws {
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

/// Box type for ``Light`` protocol that allows to decode materials in a type agnostic way.
struct AnyLight: Decodable {
    let category: LightCategory
    let name: String
    private(set) var wrapped: Light
    private var shapeIdentifier: String = ""
    
    enum CodingKeys: String, CodingKey {
        // Generic
        case type
        case name
        
        // Point light
        case transform
        case intensity
        
        // Spot light
        case falloff
        
        // Area
        case radiance
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.category = try container.decode(LightCategory.self, forKey: .type)
        self.name = try container.decode(String.self, forKey: .name)
        switch category {
        case .delta(type: .position):
            let transform = try container.decodeIfPresent(Transform.self, forKey: .transform) ?? Transform(m: Mat4.identity())
            let intensity = try container.decode(Color.self, forKey: .intensity)
            do {
                let falloff = try container.decode(Vec2.self, forKey: .falloff)
                self.wrapped = SpotLight(transform: transform, intensity: intensity, start: falloff.x, end: falloff.y)
            } catch {
                self.wrapped = PointLight(transform: transform, intensity: intensity)
            }
        case .delta(type: .direction):
            let transform = try container.decodeIfPresent(Transform.self, forKey: .transform) ?? Transform(m: Mat4.identity())
            let intensity = try container.decode(Color.self, forKey: .intensity)
            self.wrapped = ConstantEnvironmentLight(transform: transform, intensity: intensity)
        case .area:
            let radiance = try container.decode(Texture.self, forKey: .radiance)
            self.wrapped = AreaLight(texture: radiance)
        default:
            fatalError() // Not implemented
        }
    }
}

protocol Light: AnyObject {
    var category: LightCategory { get }
    func preprocess(scene: Scene)
    func sampleLi(context: LightSample.Context, sample: Vec2) -> LightSample?
    func pdfLi(context: LightSample.Context, y: Point3) -> Float
    /// Overall light emitted power
    func phi() -> Color
    /// Radiance contribution at a given point
    func L(p: Point3, n: Vec3, uv: Vec2, wo: Vec3) -> Color
    /// Radiance contribution for infinite lights
    func Le(ray: Ray) -> Color
}

extension Light {
    func L(p: Point3, n: Vec3, uv: Vec2, wo: Vec3) -> Color {
        return .zero
    }
    
    
    func Le(ray: Ray) -> Color {
        return .zero
    }
}

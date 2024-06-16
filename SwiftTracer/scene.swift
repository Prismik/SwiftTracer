//
//  scene.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-21.
//

import Foundation

final class Scene {
    public static var NB_INTERSECTION = 0
    public static var NB_TRACED_RAYS = 0
    
    let root: Shape
    let materials: [String: Material]
    let camera: Camera
    let background: Color
    let maxDepth: UInt
    let lightSampler: LightSampler

    init(root: Shape, lightSampler: LightSampler, materials: [String: Material], camera: Camera, background: Color, maxDepth: UInt) {
        self.root = root
        self.materials = materials
        self.camera = camera
        self.background = background
        self.maxDepth = maxDepth
        self.lightSampler = lightSampler
    }
    
    func hit(r: Ray) -> Intersection? {
        Scene.NB_TRACED_RAYS += 1
        return root.hit(r: r)
    }
    
    func sample(context: LightSample.Context, s: Vec2) -> LightSample? {
        // TODO Rework the sample like in bvh
        guard let source = lightSampler.sample(sample: s.x) else { return nil }
        var updated = s
        updated.x = source.s
        guard let sample = source.light.sampleLi(context: context, sample: updated) else { return nil }
        guard sample.p.visible(from: context.p, within: self) else { return nil }
        
        return LightSample(L: sample.L, wi: sample.wi, p: sample.p, pdf: source.prob * sample.pdf)
    }
}

extension Scene: Decodable {
    enum CodingKeys: String, CodingKey {
        case camera
        case background
        case materials
        case shapes
        case maxDepth
        case lights
    }

    convenience init(from decoder: Decoder) throws {
        // TODO Add sampler decoding
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let camera = try container.decode(Camera.self, forKey: .camera)
        let background = try container.decodeIfPresent(Color.self, forKey: .background) ?? Color(1, 1, 1)
        let maxDepth = try container.decodeIfPresent(UInt.self, forKey: .maxDepth) ?? 16
        let anyMaterials = try container.decode([AnyMaterial].self, forKey: .materials)
        let anyShapes = try container.decode([AnyShape].self, forKey: .shapes)
        let anyLights = try container.decode([AnyLight].self, forKey: .lights)
        
        var materials: [String: Material] = [:]
        for m in anyMaterials {
            materials[m.name] = m.wrapped
        }
        var lights: [String: Light] = [:]
        for l in anyLights {
            lights[l.name] = l.wrapped
        }

        let root = BVH(builderType: .spatial)
        for s in anyShapes {
            if let mesh = s.unwrapped(materials: materials, lights: lights) as? ShapeGroup {
                for ms in mesh.shapes {
                    ms.material = mesh.material
                    root.add(shape: ms)
                }
            } else {
                root.add(shape: s.unwrapped(materials: materials, lights: lights))
            }
        }
        
        let sampler = UniformLightSampler(lights: Array(lights.values))
        
        print("Building acceleration structures ...")
        root.build()

        self.init(
            root: root,
            lightSampler: sampler,
            materials: materials,
            camera: camera,
            background: background,
            maxDepth: maxDepth
        )
    }
}

extension Scene {
    enum Example: String {
        case simple
        case threeSpheres
        case teapot
        case triangle
        case cornelBox
        case refract
        case reflect
        case roughness
        case checkerboard = "checkerboardXY"
        case textures
        case blend
        case direct
        case veach
        case odyssey
        case odysseyTriangle = "odyssey_triangle"
        case test
        
        func create() throws -> Data {
            guard let url = Bundle.main.url(forResource: self.rawValue, withExtension: "json", subdirectory: "assets") else {
                fatalError("Trying to load obj that does not exist")
            }
            
            return try Data(contentsOf: url)
        }
    }
}

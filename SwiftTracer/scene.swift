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
    
    let root: ShapeAggregate
    let materials: [String: Material]
    let camera: Camera
    let background: Color
    let lightSampler: LightSampler
    let sampler: Sampler
    let integrator: Integrator

    init(root: ShapeAggregate, lightSampler: LightSampler, materials: [String: Material], camera: Camera, background: Color, sampler: Sampler, integrator: Integrator) {
        self.root = root
        self.materials = materials
        self.camera = camera
        self.background = background
        self.lightSampler = lightSampler
        self.sampler = sampler
        self.integrator = integrator
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
    
    func render() -> Array2d<Color> {
        return integrator.render(scene: self, sampler: sampler)
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
        case accelerator
        case sampler
        case integrator
    }

    convenience init(from decoder: Decoder) throws {
        // TODO Add sampler decoding
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let camera = try container.decode(Camera.self, forKey: .camera)
        let background = try container.decodeIfPresent(Color.self, forKey: .background) ?? Color(1, 1, 1)
        let anyMaterials = try container.decode([AnyMaterial].self, forKey: .materials)
        let anyShapes = try container.decode([AnyShape].self, forKey: .shapes)
        let anyLights = try container.decode([AnyLight].self, forKey: .lights)
        let accelerator = try container.decodeIfPresent(BVH.self, forKey: .accelerator)
        let sampler = try container.decode(AnySampler.self, forKey: .sampler).wrapped
        let integrator = try container.decode(AnyIntegrator.self, forKey: .integrator).wrapped
    
        var materials: [String: Material] = [:]
        for m in anyMaterials {
            materials[m.name] = m.wrapped
        }
        var lights: [String: Light] = [:]
        for l in anyLights {
            lights[l.name] = l.wrapped
        }

        let root: ShapeAggregate
        if let bvh = accelerator {
            root = bvh
        } else {
            root = ShapeGroup()
        }

        for s in anyShapes {
            if let mesh = s.unwrapped(materials: materials, lights: lights) as? ShapeGroup {
                for ms in mesh.shapes {
                    ms.material = mesh.material
                    ms.light = mesh.light
                    root.add(shape: ms)
                }
            } else {
                root.add(shape: s.unwrapped(materials: materials, lights: lights))
            }
        }
        
        let lightSampler = UniformLightSampler(lights: Array(lights.values))
        
        print("Building acceleration structures ...")
        let clock = ContinuousClock()
        let time = clock.measure {
            root.build()
        }
        print("Building time: \(time)")

        self.init(
            root: root,
            lightSampler: lightSampler,
            materials: materials,
            camera: camera,
            background: background,
            sampler: sampler,
            integrator: integrator
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

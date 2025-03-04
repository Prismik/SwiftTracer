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
    
    var bounds: (Point3, Float) {
        return root.aabb().boundingSphere()
    }
    let root: ShapeAggregate
    let materials: [String: Material]
    let camera: Camera
    let background: Color
    var lightSampler: LightSampler
    let sampler: Sampler
    let integrator: Integrator

    private var environmentMap: EnvironmentMapLight?

    init(root: ShapeAggregate, lightSampler: LightSampler, materials: [String: Material], camera: Camera, background: Color, sampler: Sampler, integrator: Integrator, environmentMap: EnvironmentMapLight?) {
        self.root = root
        self.materials = materials
        self.camera = camera
        self.background = background
        self.lightSampler = lightSampler
        self.sampler = sampler
        self.integrator = integrator
        self.environmentMap = environmentMap
    }
    
    func hit(r: Ray) -> Intersection? {
        Scene.NB_TRACED_RAYS += 1
        return root.hit(r: r)
    }
    
    /// Samples a light source in the scene.
    func sample(context: LightSample.Context, s: Vec2) -> LightSample? {
        // TODO Rework the sample like in bvh
        guard let source = lightSampler.sample(context: context, sample: s.x) else { return nil }
        var updated = s
        updated.x = source.s
        guard let sample = source.light.sampleLi(context: context, sample: updated) else { return nil }
        guard sample.p.visible(from: context.p, within: self) else { return nil }
        
        // TODO Check the appropriate computations for source.prob
        return LightSample(L: sample.L * source.prob, wi: sample.wi, p: sample.p, n: sample.n, pdf: sample.pdf)
    }
    
    func render() -> [PixelBuffer] {
        if let timeboxedIntegrator = integrator as? TimeboxedIntegrator {
            if timeboxedIntegrator.gradientDomain {
                let result: GradientDomainResult = timeboxedIntegrator.render(scene: self, sampler: sampler)
                return [
                    result.img,
                    result.dx.transformed { $0.abs },
                    result.dy.transformed { $0.abs },
                    result.primal
                ]
            } else {
                return [timeboxedIntegrator.render(scene: self, sampler: sampler)]
            }
        } else if let gradientIntegrator = integrator as? GradientDomainIntegrator {
            let intermediate: GradientDomainResult = gradientIntegrator.render(scene: self, sampler: sampler)
            let result = gradientIntegrator.reconstruct(using: intermediate)
            return [
                result.img,
                result.dx.transformed { $0.abs },
                result.dy.transformed { $0.abs },
                result.primal
            ]
        } else {
            return [integrator.render(scene: self, sampler: sampler)]
        }
    }
    
    func preprocess() {
        for light in lightSampler.lights {
            light.preprocess(scene: self)
        }
        
        integrator.preprocess(scene: self, sampler: sampler)
    }
    
    func environment(ray: Ray) -> Color {
        guard let envmap = environmentMap else { return background }
        
        return envmap.Le(ray: ray)
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
        var envmap: EnvironmentMapLight?
        for l in anyLights {
            let wrapped = l.wrapped
            lights[l.name] = wrapped
            if let envMapLight = wrapped as? EnvironmentMapLight {
                envmap = envMapLight
            }
        }

        var root: ShapeAggregate
        if let bvh = accelerator {
            root = bvh
        } else {
            root = ShapeGroup()
        }

        for s in anyShapes {
            let unwrapped = s.unwrapped(materials: materials, lights: lights)
            if let group = unwrapped as? ShapeGroup {
                let meshLight = lights.removeValue(forKey: s.light) as? AreaLight
                for (i, triangle) in group.shapes.enumerated() {
                    // Remove parent light, and reassign new lights for each triangles. If not present, simply assign parent material
                    if let meshLight = meshLight {
                        let triangleLight = AreaLight(texture: meshLight.texture)
                        triangleLight.shape = triangle
                        triangle.light = triangleLight
                        lights["\(s.light)_\(i)"] = triangleLight
                    } else {
                        triangle.material = group.material
                    }

                    root.add(shape: triangle)
                }
            } else {
                // Ensure reciprocal reference
                if let areaLight = unwrapped.light as? AreaLight {
                    areaLight.shape = unwrapped
                }

                root.add(shape: unwrapped)
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
            integrator: integrator,
            environmentMap: envmap
        )
    }
}

extension Point3 {
    func visible(from other: Self, within scene: Scene) -> Bool {
        var d = other - self
        var dist = d.length
        d /= dist
        dist -= 0.0002 // epsilon
        let r = Ray(origin: self, direction: d).with(max: dist)
        return scene.hit(r: r) == nil
    }
    
    func visible(from shape: Shape, within scene: Scene) -> Bool {
        return false
    }
}

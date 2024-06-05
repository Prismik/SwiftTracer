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

    init(root: Shape, materials: [String: Material], camera: Camera, background: Color, maxDepth: UInt) {
        self.root = root
        self.materials = materials
        self.camera = camera
        self.background = background
        self.maxDepth = maxDepth
    }
}

extension Scene: Decodable {
    enum CodingKeys: String, CodingKey {
        case camera
        case background
        case materials
        case shapes
        case maxDepth
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let camera = try container.decode(Camera.self, forKey: .camera)
        let background = try container.decodeIfPresent(Color.self, forKey: .background) ?? Color(1, 1, 1)
        let maxDepth = try container.decodeIfPresent(UInt.self, forKey: .maxDepth) ?? 16
        let anyMaterials = try container.decode([AnyMaterial].self, forKey: .materials)
        let anyShapes = try container.decode([AnyShape].self, forKey: .shapes)
        
        var materials: [String: Material] = [:]
        for m in anyMaterials {
            materials[m.name] = m.wrapped
        }
        
        let root = BVH(builderType: .spatial)
        for s in anyShapes {
            if let mesh = s.unwrapped(materials: materials) as? ShapeGroup {
                for var ms in mesh.shapes {
                    ms.material = mesh.material
                    root.add(shape: ms)
                }
            } else {
                root.add(shape: s.unwrapped(materials: materials))
            }
        }
        
        print("Building acceleration structures ...")
        root.build()

        self.init(
            root: root,
            materials: materials,
            camera: camera,
            background: background,
            maxDepth: maxDepth
        )
    }
    
    func hit(r: Ray) -> Intersection? {
        Scene.NB_TRACED_RAYS += 1
        return root.hit(r: r)
    }
}

extension Scene {
    enum Example: String {
        case simple
        case threeSpheres
        case teapot
        case triangle
        case cornelBox

        func create() throws -> Data {
            guard let url = Bundle.main.url(forResource: self.rawValue, withExtension: "json", subdirectory: "assets") else {
                fatalError("Trying to load obj that does not exist")
            }
            
            return try Data(contentsOf: url)
        }
    }
}

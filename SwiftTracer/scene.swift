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
        
        //let root = BVH(builderType: .sah)
        let root = ShapeGroup()
        for s in anyShapes {
            root.add(shape: s.unwrapped(materials: materials))
        }
        
        print("Building acceleration structures ...")
        //root.build()

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
    enum Example {
        case simple
        case threeSphere

        func create() -> Data {
            switch self {
            case .simple:
                let value = """
                {
                    "camera": {
                        "transform": { "o": [0, 0, 4] },
                        "fov": 45,
                        "resolution": [640, 480]
                    },
                    "background": [1, 1, 1],
                    "materials": [
                        {
                            "name": "mat_sphere",
                            "type": "diffuse",
                            "albedo": [0.6, 0.4, 0.4]
                        },
                        {
                            "name": "mat_plane",
                            "type": "diffuse",
                            "albedo": [0.75, 0.75, 0.75]
                        }
                    ],
                    "shapes": [
                        {
                            "type": "sphere",
                            "radius": 1,
                            "material": "mat_sphere"
                        },
                        {
                            "type": "quad",
                            "transform": {
                                "o": [0, -1, 0],
                                "x": [1, 0, 0],
                                "y": [0, 0, -1],
                                "z": [0, 1, 0]
                            },
                            "size": 100,
                            "material": "mat_plane"
                        }
                    ]
                }
                """
                
                let json = Data(value.utf8)
                return json
            case .threeSphere:
                let value = """
                {
                    "camera": {
                        "transform": {
                            "o": [0.7, 0, 0]
                        },
                        "vfov": 90,
                        "resolution": [640, 480]
                    },
                    "background": [
                        0, 0, 0
                    ],
                    "sampler": {
                        "type": "independent",
                        "samples": 1
                    },
                    "materials" : [
                        {
                            "name": "glass",
                            "type": "dielectric",
                            "eta_int": 1.5
                        },
                        {
                            "name": "wall",
                            "type": "diffuse"
                        },
                        {
                            "name": "light",
                            "type": "diffuse_light"
                        },
                        {
                            "name": "red ball",
                            "type": "metal",
                            "roughness": 0.1,
                            "ks" : [0.9, 0.1, 0.1]
                        },
                        {
                            "name" : "blue ball",
                            "type" : "diffuse",
                            "albedo" : [0.1, 0.1, 0.9]
                        }
                    ],
                    "shapes" : [
                        {
                            "type": "quad",
                            "size": 100,
                            "transform": [
                                {"angle": -90, "axis": [1, 0, 0]},
                                {"translate": [0, -1, 0]}
                            ],
                            "material": "wall"
                        },
                        {
                            "type": "quad",
                            "size": 100,
                            "transform": {
                                "translate": [0, 0, -10]
                            },
                            "material": "wall"
                        },
                        {
                            "type": "quad",
                            "size": 20,
                            "transform": {
                                "o": [0, 10, 0],
                                "z": [0, -1, 0],
                                "y": [0, 0, 1]
                            },
                            "material": "light"
                        },
                        {
                            "type" : "sphere",
                            "transform" : {
                                "o" : [0, 0, -2]
                            },
                            "material" : "red ball"
                        },
                        {
                            "type" : "sphere",
                            "transform" : {
                                "o" : [1.8, -0.2, -2.2]
                            },
                            "radius" : 0.8,
                            "material" : "glass"
                        },
                        {
                            "type" : "sphere",
                            "transform" : {
                                "o" : [-1.5, -0.5, -1.5]
                            },
                            "radius" : 0.5,
                            "material" : "blue ball"
                        }
                    ]
                }
                """

                let json = Data(value.utf8)
                return json
            }
        }
    }
}

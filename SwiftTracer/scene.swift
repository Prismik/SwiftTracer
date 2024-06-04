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
        case teapot
        case triangle
        case cornelBox

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
            case .teapot:
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
                            "name": "mat_teapot",
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
                            "type": "mesh",
                            "filename": "cube",
                            "material": "mat_teapot"
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
            case .triangle:
                let value = """
                {
                    "camera": {
                        "transform": {
                            "o": [0, 0, 4]
                        },
                        "vfov": 45,
                        "resolution": [640, 480]
                    },
                    "background": [
                        1, 1, 1
                    ],
                    "sampler": {
                        "type": "independent",
                        "samples": 100
                    },
                    "materials": [
                        {
                            "name": "mat_triangle",
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
                      "type": "triangle",
                      "positions": [
                        [ 0.5, 0, 0 ],
                        [ 0.5, 1, 0 ],
                        [ 1.5, 1, 0 ]
                      ],
                      "material": "mat_triangle"
                    },
                    {
                      "type": "triangle",
                      "positions": [
                        [ -1.5, 0, 0 ],
                        [ -1.5, 1, 0 ],
                        [ -0.5, 1, 0 ]
                      ],
                      "normals": [
                        [ 0, 0, 0 ],
                        [ 0, 1, 0 ],
                        [ 1, 1, 0 ]
                      ],
                      "material": "mat_triangle"
                    },
                    {
                      "type": "quad",
                      "transform": {
                        "o": [0, -1,  0],
                        "x": [1,  0,  0],
                        "y": [0,  0, -1],
                        "z": [0,  1,  0]
                      },
                      "size": 100,
                      "material": "mat_plane"
                    }
                  ]
                }
                """
                
                let json = Data(value.utf8)
                return json
            case .cornelBox:
                let value = """
                {
                    "camera": {
                        "transform": {
                            "from": [0, 20, 3000],
                            "at": [0, -4, 0],
                            "up": [0, 1, 0]
                        },
                        "vfov": 28,
                        "resolution": [1024, 1024]
                    },
                    "background": [
                        1, 1, 1
                    ],
                    "sampler": {
                        "type": "independent",
                        "samples": 100
                    },
                    "materials": [
                        {
                            "name": "white",
                            "type": "diffuse",
                            "albedo": [0.73, 0.73, 0.73]
                        },
                        {
                            "name": "green",
                            "type": "diffuse",
                            "albedo": [0.12, 0.45, 0.15]
                        },
                        {
                            "name": "red",
                            "type": "diffuse",
                            "albedo": [0.65, 0.05, 0.05]
                        },
                        {
                            "name": "tall_box",
                            "type": "diffuse",
                            "albedo": [0.725, 0.71, 0.68]
                        },
                        {
                            "name": "short_box",
                            "type": "diffuse",
                            "albedo": [0.725, 0.71, 0.68]
                        },
                        {
                            "name": "light",
                            "type": "diffuse_light"
                        }
                    ],
                    "shapes": [{
                        "transform": [
                            {
                                "scale": [59.4811, 60.4394, 60]
                            },
                            {
                                "scale": 3.0
                            },
                            {
                                "rotation": [90, 90, -153.36]
                            },
                            {
                                "o": [300, -470, 0]
                            }
                        ],
                        "filename": "cube",
                        "type": "mesh",
                        "material": "short_box"
                    }, {
                        "type": "mesh",
                        "transform": [
                            {
                                "scale": [60.7289, 59.7739, 120]
                            },
                            {
                              "scale": 3.5
                            },
                            {
                              "rotation": [90, 180, 160.812]
                            },
                            {
                              "o": [-200, -300, -300]
                            }
                        ],
                        "filename": "cube",
                        "material": "tall_box"
                    }, {
                        "type": "quad",
                        "transform": [{
                            "translate": [0, 0, -650]
                        }],
                        "size": 1300,
                        "material": "white"
                    }, {
                        "type": "quad",
                        "transform": [{
                            "axis": [1, 0, 0],
                            "angle": 90,
                        }, {
                            "translate": [0, 650, 0]
                        }],
                        "size": 1300,
                        "material": "white"
                    }, {
                        "type": "quad",
                        "transform": [{
                            "axis": [1, 0, 0],
                            "angle": -90,
                        }, {
                            "translate": [0, -650, 0]
                        }],
                        "size": 1300,
                        "material": "white"
                    }, {
                        "type": "quad",
                        "transform": [{
                            "axis": [0, 1, 0],
                            "angle": 90,
                        }, {
                            "translate": [-650, 0, 0]
                        }],
                        "size": 1300,
                        "material": "green"
                    }, {
                        "type": "quad",
                        "transform": [{
                            "axis": [0, 1, 0],
                            "angle": -90,
                        }, {
                            "translate": [650, 0, 0]
                        }],
                        "size": 1300,
                        "material": "red"
                    }, {
                        "type": "quad",
                        "transform": [
                            {
                                "axis": [1, 0, 0],
                                "angle": 90
                            },
                            {
                                "translate": [0, 640, 0]
                            }
                        ],
                        "size": 300,
                        "material": "light"
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

//
//  scene.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-21.
//

import Foundation

class Scene {
    let root: Shape
    let materials: [String: Material]
    let camera: Camera
    let background: Color
    let maxDepth: UInt

    init(root: Shape, materials: [String : Material], camera: Camera, background: Color, maxDepth: UInt) {
        self.root = root
        self.materials = materials
        self.camera = camera
        self.background = background
        self.maxDepth = maxDepth
    }
}

extension Scene: Decodable {
    required init(from decoder: Decoder) throws {
        
    }
}

extension Scene {
    enum Example {
        case simple
        
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
            }
        }
    }
}

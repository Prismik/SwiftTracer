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
 
extension Scene {
    enum Example {
        case simple
        
        func create() -> Data {
            return Data()
        }
    }
}

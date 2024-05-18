//
//  aabb.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

struct AABB {
    var min: Point3
    var max: Point3
    
    init() {
        self.min = Point3(Float.infinity, Float.infinity, Float.infinity)
        self.max = Point3(-Float.infinity, -Float.infinity, -Float.infinity) // TODO Double check
    }
    
    mutating func extend(with other: Point3) {
        self.min.x = Swift.min(self.min.x, other.x)
        self.min.y = Swift.min(self.min.y, other.y)
        self.min.z = Swift.min(self.min.z, other.z)
        
        self.max.x = Swift.max(self.max.x, other.x)
        self.max.y = Swift.max(self.max.y, other.y)
        self.max.z = Swift.max(self.max.z, other.z)
    }
}

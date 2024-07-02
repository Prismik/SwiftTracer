//
//  aabb.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

/// Bounding box denoted by a min point and a max point.
struct AABB {
    var min: Point3
    var max: Point3
    
    init() {
        self.init(
            min: Point3(Float.infinity, Float.infinity, Float.infinity),
            max: Point3(-Float.infinity, -Float.infinity, -Float.infinity) // TODO Double check
        )
    }
    
    init(min: Point3, max: Point3) {
        self.min = min
        self.max = max
    }
    
    /// Updates the bounding box, such that the new minimum will be equal to `min(self.min, other)` and the new maximum will be `max(self.max, other)`.
    mutating func extend(with other: Point3) {
        min.x = Swift.min(min.x, other.x)
        min.y = Swift.min(min.y, other.y)
        min.z = Swift.min(min.z, other.z)
        
        max.x = Swift.max(max.x, other.x)
        max.y = Swift.max(max.y, other.y)
        max.z = Swift.max(max.z, other.z)
    }
    
    /// Compute intersection with the bounding box.
    ///
    /// See [original implementation](http://psgraphics.blogspot.de/2016/02/new-simple-ray-box-test-from-andrew.html).
    func hit(r: Ray) -> Float? {
        var tMin = r.t.min
        var tMax = r.t.max
        
        for d in 0..<3 {
            // Inverse ray distance (can be optimized if this information is cached inside the ray structure)
            let dInv = 1 / r.d[d]
            
            var t0 = (min[d] - r.o[d]) * dInv
            var t1 = (max[d] - r.o[d]) * dInv
            
            // When the direction is inverse, we will hit the plane "max" before "min".
            // Thus, we will swap the two distances so t0 is always the minimum.
            if dInv < 0 {
                swap(&t0, &t1)
            }
            
            
            tMin = Swift.max(tMin, t0)
            tMax = Swift.min(tMax, t1)
            
            guard tMin < tMax else { return nil }
        }
        
        return tMin
    }

    func center() -> Point3 {
        return 0.5 * Point3(
            min.x + max.x,
            min.y + max.y,
            min.z + max.z
        )
    }

    func diagonal() -> Vec3 {
        return max - min
    }
    
    func area() -> Float {
        let e = diagonal()
        return 2 * (e.x * e.y + e.y * e.z + e.z * e.x)
    }

    /// Applies a small epsilon value to the min and max to prevent `Float` inaccuracy to cause problems.
    func sanitized() -> Self {
        var copy = self
        let diagonal = copy.diagonal()
        for i in 0..<3 {
            if diagonal[i] < 2e-4 {
                copy.min[i] -= 1e-4
                copy.max[i] += 1e-4
            }
        }
        
        return copy
    }
    
    /// Given `self` and `other` AABBs, return a new AABB where the minimum will be equal to `min(self.min, other)` and the maximum will be `max(self.max, other)`.
    func merge(with other: AABB) -> Self {
        return AABB(
            min: Point3(
                Swift.min(min.x, other.min.x),
                Swift.min(min.y, other.min.y),
                Swift.min(min.z, other.min.z)
            ),
            max: Point3(
                Swift.max(max.x, other.max.x),
                Swift.max(max.y, other.max.y),
                Swift.max(max.z, other.max.z)
            )
        )
    }
    
    func boundingSphere() -> (Point3, Float) {
        let center = center()
        return (center, (max - center).length )
    }
}

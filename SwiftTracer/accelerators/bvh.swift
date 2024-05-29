//
//  bvh.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-28.
//

import Foundation

class BVH {
    struct CachedShapeAabb {
        let aabb: AABB
        let shape: Shape
    }

    struct Node {
        enum Info {
            case leaf(firstPrimitive: Int, primitiveCount: Int)
            case node(left: Int)
        }
        
        let aabb: AABB
        var info: Info
        
        var firstPrimitive: Int {
            switch self.info {
            case .leaf(let firstPrimitive, _):
                return firstPrimitive
            case .node:
                fatalError("Not possible! Have the node already been converted?")
            }
        }
        
        var primitiveCount: Int {
            switch self.info {
            case .leaf(_, let primitiveCount):
                return primitiveCount
            case .node:
                fatalError("Not possible! Have the node already been converted?")
            }
        }
        
        init(firstPrimitive: Int, primitiveCount: Int, aabbs: [CachedShapeAabb]) {
            var aabb = AABB()
            let slice = aabbs[firstPrimitive ..< firstPrimitive + primitiveCount]
            for item in slice {
                aabb = aabb.merge(with: item.aabb)
            }
            
            self.aabb = aabb.sanitized()
            self.info = .leaf(firstPrimitive: firstPrimitive, primitiveCount: primitiveCount)
        }
        
        mutating func toNode(left: Int) {
            self.info = .node(left: left)
        }
    }
    
    enum AxisSelection {
        /// Alternate between x, y and z
        case roundRobin
        /// Take the longest axis
        case longest
    }
    
    enum Axis: Int {
        case x
        case y
        case z
        
        var next: Self {
            switch self {
            case .x: return .y
            case .y: return .z
            case .z: return .x
            }
        }
        
        func longest(v: Vec3) -> Self {
            if v.x >= v.y && v.x >= v.z {
                return .x
            }
            
            if v.y >= v.x && v.y >= v.z {
                return .y
            }
            
            return .z
        }
    }
    
    enum Builder {
        case median
        case spatial
        /// Use SAH cost to select the best axis
        /// - p^l = for left, ratio aabb area / total aabb area
        /// - t^n,l = nb object in left box
        /// - cost = p^l * t^n,l + p^r * t^n,r
        case esah
        
        var maxGroupSize: Int { return 2 }
    }
    
    let axisSelection: AxisSelection
    let builder: Builder
    let nodes: [BVH.Node]
    let shapes: [Shape]
    let currentAxis: Axis
    let lightIndexes: [Int]

    func hitBvh(r: Ray, node: BVH.Node) -> Intersection? {
        switch node.info {
        case let .leaf(firstPrimitive, primitiveCount):
            guard primitiveCount != 0 else { return nil }
            
            var intersection: Intersection? = nil
            for index in firstPrimitive ..< firstPrimitive + primitiveCount {
                let shape = shapes[index]
                if shape.aabb().hit(r: r) != nil {
                    if let i = shape.hit(r: r), i.t < r.t.max {
                        r.t = r.t.with(max: i.t)
                        intersection = i
                    }
                }
            }
            
            return intersection
        case let .node(left):
            let leftDistance = self.nodes[left].aabb.hit(r: r)
            let rightDistance = self.nodes[left + 1].aabb.hit(r: r)
            switch (leftDistance, rightDistance) {
            case let (tleft?, tright?):
                let shouldReverse = tleft > tright
                let closestIndex = shouldReverse ? left + 1 : left
                let farthestIndex = shouldReverse ? left : left + 1
                
                switch self.hitBvh(r: r, node: nodes[closestIndex]) {
                case let its?:
                    if its.t < tright {
                        return its
                    } else if let otherIts = self.hitBvh(r: r, node: nodes[farthestIndex]) {
                        return its.t < otherIts.t
                            ? its
                            : otherIts
                    } else {
                        return its
                    }
                case nil:
                    return self.hitBvh(r: r, node: nodes[farthestIndex])
                }
            case (_?, nil):
                return self.hitBvh(r: r, node: nodes[left])
            case (nil, _?):
                return self.hitBvh(r: r, node: nodes[left + 1])
            case (nil, nil):
                return nil
            }
        }
    }
}

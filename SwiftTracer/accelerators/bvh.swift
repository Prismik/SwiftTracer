//
//  bvh.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-28.
//

import Foundation

/// Recursive bvh builder
private protocol Builder {
    var maxGroupSize: Int { get }
    func build(for bvh: BVH, nodeIndex: Int, cachedAabbs: inout [CachedShapeAabb], depth: Int)
}

fileprivate struct CachedShapeAabb {
    let aabb: AABB
    let shape: Shape
}

class BVH {
    //MARK: Builders
    enum BuilderType {
        case median
        case spatial
        /// Uses SAH cost to select the best axis
        /// - p^l = for left, ratio aabb area / total aabb area
        /// - t^n,l = nb object in left box
        /// - cost = p^l * t^n,l + p^r * t^n,r
        case sah
        
        fileprivate func instance() -> Builder {
            switch self {
            case .median:
                return Median()
            case .spatial:
                return Spatial()
            default:
                return SAH()
            }
        }
    }

    private class Median: Builder {
        let maxGroupSize = 2

        func build(for bvh: BVH, nodeIndex: Int, cachedAabbs: inout [CachedShapeAabb], depth: Int) {
            let nodesCount = bvh.nodes.count
            let node = bvh.nodes[nodeIndex]
            let first = node.firstPrimitive
            let count = node.primitiveCount
            
            if count > maxGroupSize {
                cachedAabbs[first ..< first + count].sort { a, b in
                    return a.aabb.center()[bvh.currentAxis.rawValue] < b.aabb.center()[bvh.currentAxis.rawValue]
                }
                
                let leftCount = count.isMultiple(of: 2)
                ? count / 2
                : count / 2 + 1
                let rightCount = count / 2
                node.toNode(left: nodesCount)
                
                // Left + Right
                bvh.nodes.append(BVH.Node(firstPrimitive: first, primitiveCount: leftCount, aabbs: cachedAabbs))
                bvh.nodes.append(BVH.Node(firstPrimitive: first + leftCount, primitiveCount: rightCount, aabbs: cachedAabbs))
                if leftCount > maxGroupSize {
                    build(for: bvh, nodeIndex: nodesCount, cachedAabbs: &cachedAabbs, depth: depth + 1)
                }
                
                if rightCount > maxGroupSize {
                    build(for: bvh, nodeIndex: nodesCount + 1, cachedAabbs: &cachedAabbs, depth: depth + 1)
                }
            }
        }
    }
    
    private class Spatial: Builder {
        let maxGroupSize = 2
        
        func build(for bvh: BVH, nodeIndex: Int, cachedAabbs: inout [CachedShapeAabb], depth: Int) {
            let nodesCount = bvh.nodes.count
            let node = bvh.nodes[nodeIndex]
            let first = node.firstPrimitive
            let count = node.primitiveCount
            
            if count > maxGroupSize {
                let splitValue = node.aabb.center()[bvh.currentAxis.rawValue]
                cachedAabbs[first ..< first + count].sort { a, b in
                    a.aabb.center()[bvh.currentAxis.rawValue] < b.aabb.center()[bvh.currentAxis.rawValue]
                }
                
                var leftCount = 0
                for item in cachedAabbs[first ..< first + count] {
                    if item.aabb.center()[bvh.currentAxis.rawValue] < splitValue {
                        leftCount += 1
                    } else {
                        break
                    }
                }
                
                if leftCount == 0 {
                    leftCount = count / 2
                }
                let rightCount = count - leftCount
                node.toNode(left: nodesCount)
                
                // Left + Right
                bvh.nodes.append(BVH.Node(firstPrimitive: first, primitiveCount: leftCount, aabbs: cachedAabbs))
                bvh.nodes.append(BVH.Node(firstPrimitive: first + leftCount, primitiveCount: rightCount, aabbs: cachedAabbs))
                if leftCount > maxGroupSize {
                    build(for: bvh, nodeIndex: nodesCount, cachedAabbs: &cachedAabbs, depth: depth + 1)
                }
                
                if rightCount > maxGroupSize {
                    build(for: bvh, nodeIndex: nodesCount + 1, cachedAabbs: &cachedAabbs, depth: depth + 1)
                }
            }
        }
    }
    
    private class SAH: Builder {
        struct SplitParameters {
            let axis: Int
            let position: Int
            let cost: Float
        }

        let maxGroupSize = 2
        
        func build(for bvh: BVH, nodeIndex: Int, cachedAabbs: inout [CachedShapeAabb], depth: Int) {
            let nodesCount = bvh.nodes.count
            let node = bvh.nodes[nodeIndex]
            let first = node.firstPrimitive
            let count = node.primitiveCount
            
            if count > maxGroupSize {
                let scores: [[Float]] = (0 ..< 3).map { axis in
                    cachedAabbs[first ..< first + count].sort { a, b in
                        a.aabb.center()[axis] < b.aabb.center()[axis]
                    }
                    
                    return score(node: node, aabbs: &cachedAabbs)
                }
                
                let params = optimalSplitParameters(scores: scores)
                cachedAabbs[first ..< first + count].sort { a, b in
                    a.aabb.center()[params.axis] < b.aabb.center()[params.axis]
                }
                
                node.toNode(left: nodesCount)
                let leftCount = params.position == count - 1
                    ? params.position
                    : params.position + 1
                let rightCount = count - leftCount
                
                // Left + Right
                bvh.nodes.append(BVH.Node(firstPrimitive: first, primitiveCount: leftCount, aabbs: cachedAabbs))
                bvh.nodes.append(BVH.Node(firstPrimitive: first + leftCount, primitiveCount: rightCount, aabbs: cachedAabbs))
                if leftCount > maxGroupSize {
                    build(for: bvh, nodeIndex: nodesCount, cachedAabbs: &cachedAabbs, depth: depth + 1)
                }
                
                if rightCount > maxGroupSize {
                    build(for: bvh, nodeIndex: nodesCount + 1, cachedAabbs: &cachedAabbs, depth: depth + 1)
                }
            }
        }
        
        /// Scans aabbs using traversal indexes
        private func sweep(aabbs: inout [CachedShapeAabb], traversalIndexes: some Collection<Int>, scoreSize: Int, parentArea: Float) -> [Float] {
            var score = Array<Float>(repeating: 0, count: scoreSize)
            var aggregate = AABB()
            for (t, i) in traversalIndexes.enumerated() {
                aggregate = aggregate.merge(with: aabbs[i].aabb)
                score[t] += Float(t + 1) * aggregate.area() / parentArea
            }
            return score
        }
        
        /// For a node with elements [A ..< B]
        /// 1. AB = Traverse A -> B - 1, aggregating aabb on the way and computing the scores
        /// 2. BA = Traverse B -> A + 1, aggregating aabb on the way and computing the scores
        /// 3. Score = AB + BA.reverse()
        private func score(node: Node, aabbs: inout [CachedShapeAabb]) -> [Float] {
            let parentArea = node.aabb.area()
            let scoreSize = node.primitiveCount - 1
            
            // LTR
            let ltrRange = node.firstPrimitive ..< node.firstPrimitive + node.primitiveCount - 1
            let ltr = sweep(aabbs: &aabbs, traversalIndexes: ltrRange, scoreSize: scoreSize, parentArea: parentArea)
            
            // RTL
            let rtlRange = node.firstPrimitive + 1 ..< node.firstPrimitive + node.primitiveCount
            let rtl = sweep(aabbs: &aabbs, traversalIndexes: rtlRange.reversed(), scoreSize: scoreSize, parentArea: parentArea)
            
            // Merge
            return zip(ltr, rtl).map { $0 + $1 }
        }
        
        private func optimalSplitParameters(scores: [[Float]]) -> SplitParameters {
            let start = SplitParameters(axis: 0, position: Int.max, cost: Float.greatestFiniteMagnitude)
            return scores.enumerated().reduce(start) { (overall, element) in
                let (axis, score) = element
                let axisParams = score.enumerated().reduce(overall) { local, element in
                    let (i, cost) = element
                    return cost < local.cost
                        ? SplitParameters(axis: axis, position: i, cost: cost)
                        : local
                }
                
                return axisParams.cost < overall.cost
                    ? axisParams
                    : overall
            }
        }
    }

    //MARK: Node
    private class Node {
        enum Info {
            case leaf(firstPrimitive: Int, primitiveCount: Int)
            case node(left: Int)
        }
        
        let aabb: AABB
        var info: Info
        
        var firstPrimitive: Int {
            switch info {
            case .leaf(let firstPrimitive, _):
                return firstPrimitive
            case .node:
                fatalError("Not possible! Have the node already been converted?")
            }
        }
        
        var primitiveCount: Int {
            switch info {
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
        
        func toNode(left: Int) {
            self.info = .node(left: left)
        }
    }
    
    //MARK: Axis
    enum AxisSelection {
        /// Alternate between x, y and z
        case roundRobin
        /// Take the longest axis
        case longest
    }
    
    private enum Axis: Int {
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
    
    //MARK: BVH
    private let axisSelection: AxisSelection
    private let builder: Builder
    private let currentAxis: Axis
    private var nodes: [BVH.Node]
    private var shapes: [Shape]
    private var lightIndexes: [Int]

    init(builderType: BuilderType) {
        self.axisSelection = .roundRobin
        self.builder = builderType.instance()
        self.nodes = []
        self.shapes = []
        self.currentAxis = .x
        self.lightIndexes = []
    }

    func add(shape: Shape) {
        shapes.append(shape)
    }
    
    func build() {
        guard nodes.isEmpty else {
            return print("WARNING! Trying to rebuild an already built BVH")
        }
        
        var cachedAabbs: [CachedShapeAabb] = shapes.map {
            CachedShapeAabb(aabb: $0.aabb(), shape: $0)
        }
        nodes.append(Node(firstPrimitive: 0, primitiveCount: cachedAabbs.count, aabbs: cachedAabbs))
        builder.build(for: self, nodeIndex: 0, cachedAabbs: &cachedAabbs, depth: 0)
        
        shapes = cachedAabbs.map { $0.shape }
        for (i, s) in shapes.enumerated() {
            if s.material.hasEmission {
                lightIndexes.append(i)
            }
        }
    }

    private func hitBvh(r: Ray, node: BVH.Node) -> Intersection? {
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
            let leftDistance = nodes[left].aabb.hit(r: r)
            let rightDistance = nodes[left + 1].aabb.hit(r: r)
            switch (leftDistance, rightDistance) {
            case let (tleft?, tright?):
                let shouldReverse = tleft > tright
                let closestIndex = shouldReverse ? left + 1 : left
                let farthestIndex = shouldReverse ? left : left + 1
                
                switch hitBvh(r: r, node: nodes[closestIndex]) {
                case let its?:
                    if its.t < tright {
                        return its
                    } else if let otherIts = hitBvh(r: r, node: nodes[farthestIndex]) {
                        return its.t < otherIts.t
                            ? its
                            : otherIts
                    } else {
                        return its
                    }
                case nil:
                    return hitBvh(r: r, node: nodes[farthestIndex])
                }
            case (_?, nil):
                return hitBvh(r: r, node: nodes[left])
            case (nil, _?):
                return hitBvh(r: r, node: nodes[left + 1])
            case (nil, nil):
                return nil
            }
        }
    }
}

extension BVH: Shape {
    func hit(r: Ray) -> Intersection? {
        guard !nodes.isEmpty else { return nil }
        switch nodes[0].aabb.hit(r: r) {
        case _?:
            return hitBvh(r: r, node: nodes[0])
        case nil:
            return nil
        }
    }
    
    func aabb() -> AABB {
        return nodes.isEmpty
            ? AABB()
            : nodes[0].aabb
    }
    
    func sampleDirect(p: Point3, sample: Vec2) -> EmitterSample {
        let n = Float(lightIndexes.count)
        var rng = sample
        let j = floor(sample.x * n)
        let idx = lightIndexes[Int(j)]
        rng.x = sample.x * n - j
        let shape = shapes[idx]
        let e = shape.sampleDirect(p: p, sample: rng)
        let pdf = pdfDirect(shape: shape, p: p, y: e.y, n: e.n)
        return EmitterSample(y: e.y, n: e.n, uv: e.uv, pdf: pdf)
    }
    
    func pdfDirect(shape: Shape, p: Point3, y: Point3, n: Vec3) -> Float {
        let marginal: Float = 1 / Float(lightIndexes.count)
        let conditional = shape.pdfDirect(shape: shape, p: p, y: y, n: n)
        return marginal * conditional
    }
    
    var material: Material! {
        get { return shapes.first?.material }
        set { /* no op */ }
    }
}

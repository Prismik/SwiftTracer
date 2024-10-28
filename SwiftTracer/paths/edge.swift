//
//  edge.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

struct Edge {
    var start: any Vertex
    var end: Vertex
    let d: Vec3
    let distance: Float
    let distanceSquared: Float
    var weight: Color
    var contribution: Color
    var pdf: Float
    let connector: Bool

    private init(start: any Vertex, end: any Vertex, weight: Color, contribution: Color, pdf: Float, connector: Bool) {
        self.start = start
        self.end = end
        let direction = (end.position - start.position)
        self.distance = direction.length
        self.distanceSquared = direction.lengthSquared
        self.d = direction.normalized()
        self.weight = weight
        self.contribution = contribution
        self.pdf = pdf
        self.connector = connector
    }
    
    static func make(start: any Vertex, end: any Vertex, weight: Color, contribution: Color, pdf: Float) -> Edge {
        var edge = Edge(start: start, end: end, weight: weight, contribution: contribution, pdf: pdf, connector: false)
        edge.start.outgoing = edge
        edge.end.incoming = edge
        return edge
    }
    
    /// Creates an edge and assign the weight based on the intersection of a ray from `start` to `end`.
    static func connector(start: any Vertex, end: any Vertex, pdf: Float, scene: Scene, replacedEdge: Edge) -> Edge {
        var edge = Edge(start: start, end: end, weight: .zero, contribution: .zero, pdf: pdf, connector: true)
        guard let v = end as? SurfaceVertex else { return edge }
        edge.start.outgoing = edge
        edge.end.incoming = edge
        edge.pdf = edge.p()

        var contrib = Color()
        guard let intersection = end.intersection else { return edge }
        
        let ctx = LightSample.Context(p: intersection.p, n: intersection.n, ns: intersection.n)
        let jacobian = computeJacobian(main: edge, shifted: replacedEdge)
        if let lightSample = scene.sample(context: ctx, s: v.indirectRng) {
            let frame = Frame(n: intersection.n)
            let localWo = frame.toLocal(v: -edge.d).normalized()
            let localWi = frame.toLocal(v: lightSample.wi).normalized()
            let bsdfPdf = intersection.shape.material.pdf(wo: localWo, wi: localWi, uv: intersection.uv, p: intersection.p)
            let bsdfEval = intersection.shape.material.evaluate(wo: localWo, wi: localWi, uv: intersection.uv, p: intersection.p)
            let weight = lightSample.pdf / (bsdfPdf + lightSample.pdf)

            // TODO Review how jacobian is computed for light sampling
//            let radiance = lightSample.L * (lightSample.pdf / v.indirectPdf)
//            let squaredDist = (intersection.p - lightSample.p).lengthSquared
//            lightSample.n.dot(lightSample.wi)
//            let cosLight = lightSample.n.dot(.unit(.z))
            
            // TODO Not sure about edge.pdf
//            let shiftWeightDem = (jacobian * (edge.pdf / pdf)) * (lightSample.pdf + bsdfPdf)
//            let weight = v.indirectPdf / (v.indirectDem + shiftWeightDem)
            contrib = (weight * bsdfEval / lightSample.pdf) * lightSample.L
        }
        
        
        edge.contribution = contrib
        edge.weight = edge.eval() / replacedEdge.pdf
//        edge.pdf *= jacobian
        
        return edge
    }

    private func eval() -> Color {
        guard let intersection = end.intersection else { return .zero }
        // TODO Small problem here where outgoing is nil
        guard let next = end.outgoing else { return .zero }

        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -d)
        let wi = frame.toLocal(v: next.d)
        return intersection.shape.material.evaluate(wo: wo, wi: wi, uv: intersection.uv, p: intersection.p)
    }
    
    private func p() -> Float {
        guard let intersection = end.intersection else { return .zero }
        // TODO Small problem here where outgoing is nil
        guard let next = end.outgoing else { return .zero }

        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -d)
        let wi = frame.toLocal(v: next.d)
        return intersection.shape.material.pdf(wo: wo, wi: wi, uv: intersection.uv, p: intersection.p)
    }
    
    private static func computeJacobian(main: Edge, shifted: Edge) -> Float {
        guard let normal = main.end.intersection?.n else { return 0 }

        let mainCos = main.d.dot(normal)
        let shiftedCos = shifted.d.dot(normal)
        return abs(shiftedCos * main.distanceSquared) / (Float.leastNonzeroMagnitude + abs(mainCos * shifted.distanceSquared))
    }
}

extension Edge: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.d == rhs.d && lhs.distance == rhs.distance && lhs.weight == rhs.weight && lhs.contribution == rhs.contribution
    }
}

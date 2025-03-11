//
//  shiftMapping.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

import Collections

enum ShiftMappingOperator: String, Decodable {
    case rsr
    case pathReconnection
}

struct AnyShiftMappingOperator: Decodable {
    enum CodingKeys: String, CodingKey {
        case type
        case params
    }
    
    let wrapped: ShiftMapping
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ShiftMappingOperator.self, forKey: .type)
        switch type {
        case .rsr:
            wrapped = RandomSequenceReplay()
        case .pathReconnection:
            wrapped = PathReconnection()
        }
    }
}

struct ShiftResult {
    var main: Color
    /// Main contribution without the MIS from shifts
    var mainPrime: Color
    var directLight: Color
    var radiances: [Color]
    var gradients: [Color]
    
    init() {
        main = .zero
        mainPrime = .zero
        directLight = .zero
        radiances = Array(repeating: .zero, count: 4)
        gradients = Array(repeating: .zero, count: 4)
    }
}

protocol ShiftMapping {
    var gradientOffsets: OrderedSet<Vec2> { get }
    var identifier: String { get }
    /// Calculating the contribution of shifted pixels along with the base path and their finite differences.
    func shift(
        pixel: Vec2,
        sampler: Sampler,
        params: ShiftMappingParams
    ) -> ShiftResult
    
    func initialize(scene: Scene)
}

struct ShiftMappingParams {
    let offsets: Set<Vec2>?
}

enum RayState {
    struct Data {
        var pdf: Float
        var ray: Ray
        var its: Intersection
        var throughput: Color
    }

    case fresh(data: Data)
    case connected(data: Data)
    case connectedRecently(data: Data)
    case dead
    
    func sanitized() -> RayState {
        return switch self {
        case .dead: .dead
        case .fresh(let e):
            Frame(n: e.its.n).toLocal(v: -e.ray.d).z <= 0 ? .dead : .fresh(data: e)
        case .connectedRecently(let e):
            e.its.n.dot(e.ray.d) > 0 ? .dead : .connectedRecently(data: e)
        case .connected(let e): .connected(data: e)
        }
    }
    
    static func new(pixel: Vec2, offset: Vec2, scene: Scene) -> RayState {
        let pixel = pixel + offset
        let max = scene.camera.resolution
        guard (0 ..< max.x).contains(pixel.x) && (0 ..< max.y).contains(pixel.y) else {
            return .dead
        }
        
        let ray = scene.camera.createRay(from: pixel)
        guard let its = scene.hit(r: ray) else { return .dead }
        return .fresh(data: Data(pdf: 1, ray: ray, its: its, throughput: Color(repeating: 1)))
    }
}

// MARK:  Random sequence replay

final class RandomSequenceReplay: ShiftMapping {
    let identifier = "rsr"

    unowned var scene: Scene!
    
    let gradientOffsets: OrderedSet = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]
    
    func initialize(scene: Scene) {
        self.scene = scene
    }
    
    func shift(pixel: Vec2, sampler: Sampler, params: ShiftMappingParams) -> ShiftResult {
        let filteredOffsets = params.offsets.map { o in gradientOffsets.union(o) } ?? gradientOffsets

        let replaySampler = ReplaySampler(sampler: sampler, random: [])
        let base = trace(pixel: pixel, scene: scene, sampler: replaySampler)
    
        var li = ShiftResult()
        let offsets: [ShiftResult] = filteredOffsets.map {
            let shiftSampler = ReplaySampler(sampler: sampler, random: replaySampler.random)
            let shift = pixel + $0
            let max = scene.camera.resolution
            guard (0 ..< max.x).contains(shift.x) && (0 ..< max.y).contains(shift.y) else { return ShiftResult() }
            
            return trace(pixel: shift, scene: scene, sampler: shiftSampler)
        }

        li.main += base.main * 4 * 0.5
        li.directLight += base.directLight
        li.radiances = offsets.map { $0.main * 0.5 }
        li.gradients = offsets.map { ($0.main - base.main) * 0.5 }
        return li
    }
    
    private func trace(pixel: Vec2, scene: Scene, sampler: Sampler) -> ShiftResult {
        var li = ShiftResult()
        let ray = scene.camera.createRay(from: pixel)
        guard let intersection = scene.hit(r: ray) else {
            li.main = scene.background
            return li
        }
        
        if intersection.hasEmission {
            let frame = Frame(n: intersection.n)
            let wo = frame.toLocal(v: -ray.d).normalized()
            li.directLight += intersection.shape.light.L(p: intersection.p, n: intersection.n, uv: intersection.uv, wo: wo)
        } else {
            li.main += trace(intersection: intersection, ray: ray, scene: scene, sampler: sampler, depth: 0)
        }
        
        return li
    }
    
    private func trace(intersection: Intersection?, ray: Ray, scene: Scene, sampler: Sampler, depth: Int) -> Color {
        guard ray.d.length.isFinite else { return .zero }
        guard let intersection = intersection else { return scene.background }
        var contribution = Color()
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        
        guard !intersection.hasEmission else {
            return intersection.shape.light.L(p: intersection.p, n: intersection.n, uv: intersection.uv, wo: wo)
        }

        // MIS Emitter
        contribution += light(wo: wo, scene: scene, frame: frame, intersection: intersection, s: sampler.next2())

        // MIS Material
        guard let direction = intersection.shape.material.sample(wo: wo, uv: intersection.uv, p: intersection.p, sample: sampler.next2()) else {
            return contribution
        }
        
        let bsdfWeight = direction.weight
        let wi = frame.toWorld(v: direction.wi).normalized()
        let newRay = Ray(origin: intersection.p, direction: wi)
        var its: Intersection? = nil
        if let newIntersection = scene.hit(r: newRay) {
            its = newIntersection
            if newIntersection.hasEmission, let light = newIntersection.shape.light {
                let localFrame = Frame(n: newIntersection.n)
                let newWo = localFrame.toLocal(v: -newRay.d).normalized()
                let pdf = intersection.shape.material.pdf(wo: wo, wi: direction.wi, uv: intersection.uv, p: intersection.p)
                var weight: Float = 1
                if !intersection.shape.material.hasDelta(uv: intersection.uv, p: intersection.p) {
                    let ctx = LightSample.Context(p: intersection.p, n: intersection.n, ns: intersection.n)
                    let pdfDirect = light.pdfLi(context: ctx, y: newIntersection.p)
                    weight = pdf / (pdf + pdfDirect)
                }

                contribution += (weight * bsdfWeight)
                    * light.L(p: newIntersection.p, n: newIntersection.n, uv: newIntersection.uv, wo: newWo)
            }
        }

        // TODO Max depth - min depth
        return depth == 16 || (its?.hasEmission == true && depth >= 0)
            ? contribution
            : contribution + trace(intersection: its, ray: newRay, scene: scene, sampler: sampler, depth: depth + 1) * bsdfWeight
    }
    
    private func light(wo: Vec3, scene: Scene, frame: Frame, intersection: Intersection, s: Vec2) -> Color {
        guard !intersection.shape.material.hasDelta(uv: intersection.uv, p: intersection.p) else { return .zero }

        let ctx = LightSample.Context(p: intersection.p, n: intersection.n, ns: intersection.n)
        guard let lightSample = scene.sample(context: ctx, s: s) else { return .zero }

        let localWi = frame.toLocal(v: lightSample.wi).normalized()
        let pdf = intersection.shape.material.pdf(wo: wo, wi: localWi, uv: intersection.uv, p: intersection.p)
        let eval = intersection.shape.material.evaluate(wo: wo, wi: localWi, uv: intersection.uv, p: intersection.p)
        let weight = lightSample.pdf / (pdf + lightSample.pdf)
        
        return (weight * eval / lightSample.pdf) * lightSample.L
    }
}

// MARK:  Path reconnection

final class PathReconnection: ShiftMapping {
    let identifier = "pathReconnect"
    
    struct Stats {
        var successfulConnections: Int = 0
        var failedConnections: Int = 0
        var total: Int { successfulConnections + failedConnections }
    }

    unowned var scene: Scene!

    var stats = Stats()

    let gradientOffsets: OrderedSet = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]

    func initialize(scene: Scene) {
        self.scene = scene
        
    }
    
    func shift(pixel: Vec2, sampler: Sampler, params: ShiftMappingParams) -> ShiftResult {
        let filteredOffsets = params.offsets.map { o in gradientOffsets.union(o) } ?? gradientOffsets

        // TODO
        let maxDepth = 16
        let minDepth = 0
        
        var li = ShiftResult()
        guard var main: RayState.Data = switch RayState.new(pixel: pixel, offset: .zero, scene: scene) {
            case .dead: nil
            case .connected(let data), .connectedRecently(let data), .fresh(let data): data
        } else {
            return li
        }
        
        var offsets = filteredOffsets.map { RayState.new(pixel: pixel, offset: $0, scene: scene) }
        
        var depth = 1
        while depth <= maxDepth && depth >= minDepth {
            offsets = offsets.map { $0.sanitized() }

            if main.its.hasEmission && depth == 1 {
                let frame = Frame(n: main.its.n)
                let wo = frame.toLocal(v: -main.ray.d)
                li.directLight += main.its.shape.light.L(p: main.its.p, n: main.its.n, uv: main.its.uv, wo: wo)
            }
            
            if !main.its.hasEmission && !main.its.shape.material.hasDelta(uv: main.its.uv, p: main.its.p) {
                light(main: &main, offsets: offsets, li: &li, sampler: sampler) // Direct light sampling
            }
        
            // Sample material, or return current values if it fails
            guard let updated = bsdf(main: &main, offsets: offsets, li: &li, sampler: sampler) else { return li }
            offsets = updated
            depth += 1
        }

        return li
    }
    
    /// Computes next event estimation lighting
    private func light(main: inout RayState.Data, offsets: [RayState], li: inout ShiftResult, sampler: Sampler) -> Void {
        let rngLight = sampler.next2()
        guard let lightSample = scene.sample(context: LightSample.Context(p: main.its.p, n: main.its.n, ns: main.its.n), s: rngLight) else { return }
        let mainFrame = Frame(n: main.its.n)
        let mainLightOutLocal: Vec3 = mainFrame.toLocal(v: lightSample.wi).normalized()
        let mainLightInLocal = mainFrame.toLocal(v: -main.ray.d).normalized()
        let mainBsdfEval = main.its.shape.material.evaluate(wo: mainLightInLocal, wi: mainLightOutLocal, uv: main.its.uv, p: main.its.p)
        let mainBsdfPdf = main.its.shape.material.pdf(wo: mainLightInLocal, wi: mainLightOutLocal, uv: main.its.uv, p: main.its.p)

        let mainWeightNum = lightSample.pdf
        let mainWeightDem = lightSample.pdf + mainBsdfPdf
        let mainContrib = main.throughput * mainBsdfEval * lightSample.L / lightSample.pdf
        let mainGeometrySquaredLength = (main.its.p - lightSample.p).lengthSquared
        let mainGeometryCosLight = lightSample.n.dot(lightSample.wi)
        // Compute shift maps
        for (i, o) in offsets.enumerated() {
            let result: (shiftWeightDem: Float, shiftContrib: Color)
            switch o {
            case .dead: result = (mainWeightNum / (0.0001 + mainWeightDem), .zero)
            case .connected(let s):
                let dem = (s.pdf / main.pdf) * (lightSample.pdf + mainBsdfPdf)
                let contrib = s.throughput * mainBsdfEval * lightSample.L / lightSample.pdf
                result = (dem, contrib)
            case .connectedRecently(let s):
                let shiftDirectionInGlobal = (s.its.p - main.its.p).normalized()
                let shiftDirectionInLocal = mainFrame.toLocal(v: shiftDirectionInGlobal).normalized()
                guard shiftDirectionInLocal.z > 0 else { result = (0.0, Color.zero); break }

                let shiftBsdfPdf = main.its.shape.material.pdf(wo: shiftDirectionInLocal, wi: mainLightOutLocal, uv: s.its.uv, p: s.its.p)
                let shiftBsdfValue = main.its.shape.material.evaluate(wo: shiftDirectionInLocal, wi: mainLightOutLocal, uv: s.its.uv, p: s.its.p)
                let weightDem = (s.pdf / main.pdf) * (lightSample.pdf + shiftBsdfPdf)
                let contrib = s.throughput * shiftBsdfValue * lightSample.L / lightSample.pdf
                result = (weightDem, contrib)
            case .fresh(let s):
                guard !s.its.hasEmission else { result = (1, .zero); break }
                
                let ctx = LightSample.Context(p: s.its.p, n: s.its.n, ns: s.its.n)
                let frame = Frame(n: s.its.n)
                guard let shiftLightSample = scene.sample(context: ctx, s: rngLight) else { result = (0, .zero); break }

                let shiftEmmiterRadiance = shiftLightSample.L * (shiftLightSample.pdf / lightSample.pdf)
                let shiftDirectionOutLocal = frame.toLocal(v: shiftLightSample.wi).normalized()
                let shiftFrame = Frame(n: s.its.n)
                let shiftInLocal = shiftFrame.toLocal(v: -s.ray.d).normalized()
                let shiftBsdfValue = s.its.shape.material.evaluate(wo: shiftInLocal, wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                let shiftBsdfPdf = s.its.shape.material.pdf(wo: shiftInLocal, wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                let jacobian = (shiftLightSample.n.dot(shiftLightSample.wi) * mainGeometrySquaredLength).abs()
                    / (mainGeometryCosLight * (s.its.p - shiftLightSample.p).lengthSquared).abs()
                
                assert(jacobian.isFinite)
                assert(jacobian >= 0)
                let weightDem = (jacobian * (s.pdf / main.pdf)) * (shiftLightSample.pdf + shiftBsdfPdf)
                let contrib = jacobian * s.throughput * shiftBsdfValue * shiftEmmiterRadiance / shiftLightSample.pdf
                result = (weightDem, contrib)
            }
            
            let weight = mainWeightNum / (mainWeightDem + result.shiftWeightDem)
            assert(weight.isFinite)
            assert(weight >= 0 && weight <= 1)
            li.main += mainContrib * weight
            li.mainPrime += mainContrib * mainWeightNum / mainWeightDem
            li.radiances[i] += result.shiftContrib * weight
            li.gradients[i] += (result.shiftContrib - mainContrib) * weight
        }
    }

    /// Computes the throughput resulting from bounces on a bsdf
    private func bsdf(main: inout RayState.Data, offsets: [RayState], li: inout ShiftResult, sampler: Sampler) -> [RayState]? {
        let frame = Frame(n: main.its.n)
        let wo = frame.toLocal(v: -main.ray.d).normalized()
        guard !main.its.hasEmission, let mainSampledBsdf = main.its.shape.material.sample(wo: wo, uv: main.its.uv, p: main.its.p, sample: sampler.next2()) else { return nil }
        
        let mainDirectionOutGlobal = frame.toWorld(v: mainSampledBsdf.wi).normalized()
        main.ray = Ray(origin: main.its.p, direction: mainDirectionOutGlobal)
        let mainPrevIts = main.its
        guard let newIts = scene.hit(r: main.ray) else { return nil }
        main.its = newIts
        
        // Check if metal -> check if roughness is above treshold
        let prevRoughness: Float = (mainPrevIts.shape.material as? Metal)?.roughness.get(uv: mainPrevIts.uv, p: mainPrevIts.p) ?? 1.0
        let prevDelta = mainPrevIts.shape.material?.hasDelta(uv: mainPrevIts.uv, p: mainPrevIts.p) ?? false
        let currentRoughness: Float = (newIts.shape.material as? Metal)?.roughness.get(uv: newIts.uv, p: newIts.p) ?? 1.0
        let currentDelta = newIts.shape.material?.hasDelta(uv: newIts.uv, p: newIts.p) ?? false
        let treshold: Float = 0.3
        let prevRough = prevRoughness > treshold && !prevDelta
        let connectable = prevRoughness > treshold && !prevDelta && currentRoughness > treshold && !currentDelta
        
        // Check if the bsdf bounces to a light source
        let bounceLight: Light?  = if main.its.hasEmission { main.its.shape.light } else { nil }
        let bounceLightPdf: Float = bounceLight.map {
            let ctx = LightSample.Context(p: mainPrevIts.p, n: mainPrevIts.n, ns: mainPrevIts.n)
            return $0.pdfLi(context: ctx, y: main.its.p)
        } ?? 0
        let bounceLightRadiance: Color = bounceLight.map {
            let frame = Frame(n: main.its.n)
            let wo = frame.toLocal(v: -main.ray.d).normalized()
            return $0.L(p: main.its.p, n: main.its.n, uv: main.its.uv, wo: wo)
        } ?? .zero
        
        let mainPdfPrev = main.pdf
        main.throughput *= mainSampledBsdf.weight
        main.pdf *= mainSampledBsdf.pdf
        guard main.pdf != 0 && main.throughput != .zero else { return nil }
        
        let mainBsdfContrib = main.throughput * bounceLightRadiance
        return offsets.enumerated().map { (i, o) in
            let result: (weightDem: Float, contrib: Color, state: RayState, halfVector: Bool)
            switch o {
            case .dead: result = (0, .zero, .dead, false)
            case .connected(let s):
                let newThroughput = s.throughput * mainSampledBsdf.weight
                let newPdf = s.pdf * mainSampledBsdf.pdf
                let shiftWeightDem = (s.pdf / mainPdfPrev) * (mainSampledBsdf.pdf + bounceLightPdf)
                let shiftContrib = newThroughput * bounceLightRadiance
                result = (
                    shiftWeightDem,
                    shiftContrib,
                    .connected(data: RayState.Data(pdf: newPdf, ray: s.ray, its: s.its, throughput: newThroughput)),
                    false
                )
            case .connectedRecently(let s):
                guard mainPrevIts.shape.material.hasDelta(uv: mainPrevIts.uv, p: mainPrevIts.p) == false else { result = (0.0, .zero, .dead, false); break }
                
                let frame = Frame(n: mainPrevIts.n)
                let shiftDirectionInGlobal = (s.its.p - main.ray.o).normalized()
                let shiftDirectionInLocal = frame.toLocal(v: shiftDirectionInGlobal).normalized()
                guard shiftDirectionInLocal.z > 0 else { result = (0.0, .zero, .dead, false); break }
                
                let shiftBsdfPdf = mainPrevIts.shape.material.pdf(wo: shiftDirectionInLocal, wi: mainSampledBsdf.wi, uv: mainPrevIts.uv, p: mainPrevIts.p)
                let shiftBsdfValue = mainPrevIts.shape.material.evaluate(wo: shiftDirectionInLocal, wi: mainSampledBsdf.wi, uv: mainPrevIts.uv, p: mainPrevIts.p)
                let newThroughput = s.throughput * (shiftBsdfValue / mainSampledBsdf.pdf)
                let newPdf = s.pdf * shiftBsdfPdf
                let shiftWeightDem = (s.pdf / mainPdfPrev) * (shiftBsdfPdf + bounceLightPdf)
                let shiftContrib = newThroughput * bounceLightRadiance
                result = (
                    shiftWeightDem,
                    shiftContrib,
                    .connected(data: RayState.Data(pdf: newPdf, ray: s.ray, its: s.its, throughput: newThroughput)),
                    false
                )
            case .fresh(let s):
                guard !s.its.hasEmission && s.its.p.visible(from: main.its.p, within: scene) else { result = (0.0, .zero, .dead, false); break }
                
                let shiftRough = !s.its.shape.material.hasDelta(uv: s.its.uv, p: s.its.p)
                    && (s.its.shape.material as? Metal)?.roughness.get(uv: s.its.uv, p: s.its.p) ?? 1.0 > treshold
                
                // Current surface and next one are considered rough (diffuse or metal with roughness above treshold)
                if connectable {
                    let frame = Frame(n: s.its.n)
                    let shiftDirectionOutGlobal = (main.its.p - s.its.p).normalized()
                    let shiftDirectionOutLocal = frame.toLocal(v: shiftDirectionOutGlobal).normalized()
                    
                    let jacobian = (main.its.n.dot(-shiftDirectionOutGlobal) * main.its.t.pow(2)).abs()
                    / (main.its.n.dot(-main.ray.d) * (s.its.p - main.its.p).lengthSquared).abs()
                    assert(jacobian.isFinite)
                    assert(jacobian >= 0)
                    
                    let shiftBsdfValue = s.its.shape.material.evaluate(wo: frame.toLocal(v: -s.ray.d), wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                    let shiftBsdfPdf = s.its.shape.material.pdf(wo: frame.toLocal(v: -s.ray.d), wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                    let newThroughput = s.throughput * shiftBsdfValue * (jacobian / mainSampledBsdf.pdf)
                    let newPdf = s.pdf * shiftBsdfPdf * jacobian
                    let pair: (shiftLightRadiance: Color, shiftLightPdf: Float) = bounceLight.map { _ in
                        guard bounceLightPdf != 0 else { return (.zero, 0) }
                        let ctx = LightSample.Context(p: s.its.p, n: s.its.n, ns: s.its.n)
                        let pdf = main.its.shape.light.pdfLi(context: ctx, y: main.its.p)
                        return (shiftLightRadiance: bounceLightRadiance, shiftLightPdf: pdf)
                    } ?? (.zero, 0)
                    
                    let shiftWeightDem = (s.pdf / mainPdfPrev) * (shiftBsdfPdf + pair.shiftLightPdf)
                    let shiftContrib = newThroughput * pair.shiftLightRadiance
                    result = (
                        shiftWeightDem,
                        shiftContrib,
                        .connectedRecently(data: RayState.Data(pdf: newPdf, ray: s.ray, its: s.its, throughput: newThroughput)),
                        false
                    )
                } else {
                    let frame = Frame(n: s.its.n)
                    let shiftSuccess: Bool
                    let shiftWo: Vec3
                    let tanSpaceMainWi: Vec3 = mainPrevIts.wi
                    let tanSpaceMainWo: Vec3 = mainSampledBsdf.wi
                    let tanSpaceShiftWi: Vec3 = s.its.wi
                    if tanSpaceMainWi.z * tanSpaceMainWo.z < 0 {
                        // Refract
                        
                        let mainEta: Float = mainSampledBsdf.eta
                        let shiftEta: Float = (s.its.shape.material as? Dielectric)?.etaInterior ?? 1.0
                        // TODO Make ETA of surfaces available; when either are equal to 1, fail the shift
                        
                        let tanSpaceHalfVectorUnorm: Vec3 = tanSpaceMainWi.z < 0
                            ? -(tanSpaceMainWi * mainEta + tanSpaceMainWo)
                            : -(tanSpaceMainWi + mainEta * tanSpaceMainWo)
                        
                        let tangentSpaceHalfVector: Vec3 = tanSpaceHalfVectorUnorm.normalized()
                        
                        let tanSpaceShiftWo: Vec3 = tanSpaceShiftWi.refract(n: tangentSpaceHalfVector, eta: shiftEta)
                        
                        if tanSpaceShiftWo.length != 0 {
                            shiftWo = .zero
                            shiftSuccess = false
                        } else {
                            // TODO Compute jacobian if necessary

                            shiftWo = tanSpaceShiftWo
                            shiftSuccess = true
                        }
                        
                        
                    } else {
                        // Reflect
                        let tanSpaceHvMain = (tanSpaceMainWo + tanSpaceMainWi).normalized()
                        shiftWo = -tanSpaceShiftWi + tanSpaceHvMain * 2 * tanSpaceShiftWi.dot(tanSpaceHvMain)
                        shiftSuccess = true
                    }
                    
                    let success = !shiftRough && !prevRough && shiftSuccess
                    let jacobian: Float = 1.0
                    if success {
                        let newThroughput = s.throughput * jacobian * s.its.shape.material.evaluate(wo: shiftWo, wi: s.its.wi, uv: s.its.uv, p: s.its.p)
                        
                        if newThroughput.luminance.isInfinite || newThroughput.luminance.isNaN {
                            print("Error in throughput calculation")
                        }
                        let newPdf = s.pdf * jacobian * s.its.shape.material.pdf(wo: shiftWo, wi: s.its.wi, uv: s.its.uv, p: s.its.p)
                        let shiftDirectionOutGlobal = frame.toWorld(v: shiftWo).normalized()
                        let ray = Ray(origin: s.its.p, direction: shiftDirectionOutGlobal)
                        guard let newShiftIts = scene.hit(r: ray) else { result = (0, .zero, .dead, true); break }
                        
                        let shiftEmitterRadiance: Color = newShiftIts.hasEmission
                            ? newShiftIts.shape.light.L(p: s.its.p, n: s.its.n, uv: s.its.uv, wo: shiftDirectionOutGlobal)
                            : .zero
                        let newState: RayState = .fresh(data: RayState.Data(pdf: newPdf, ray: ray, its: newShiftIts, throughput: newThroughput))
                        
                        if newPdf.isNaN || newPdf.isInfinite {
                            print("Error in pdf calculation")
                        }
                        result = (newPdf, newThroughput * shiftEmitterRadiance, newState, true)
                    } else {
                        result = (0, .zero, .dead, true)
                    }
                }
            }
            
            let lightDem = bounceLightPdf == 0 ? 1 : bounceLightPdf
            let mainWeightDem: Float = result.halfVector
                ? mainSampledBsdf.pdf
                : mainSampledBsdf.pdf + bounceLightPdf
            let weight = mainSampledBsdf.pdf / (mainWeightDem + result.weightDem + 0.0000001)
            assert(weight.isFinite)
            assert(weight >= 0 && weight <= 1)
            li.main += mainBsdfContrib * weight / lightDem
            li.mainPrime += mainBsdfContrib * mainSampledBsdf.pdf / mainWeightDem
            li.radiances[i] += result.contrib * weight / lightDem
            li.gradients[i] += (result.contrib / lightDem - mainBsdfContrib / lightDem) * weight
            return result.state
        }
    }
}

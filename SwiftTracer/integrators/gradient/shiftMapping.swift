//
//  shiftMapping.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

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
    var radiances: [Color]
    var gradients: [Color]
    
    init() {
        main = .zero
        radiances = Array(repeating: .zero, count: 4)
        gradients = Array(repeating: .zero, count: 4)
    }
}

protocol ShiftMapping {
    /// Tries calculating the contribution of a shifted pixel, returning nil when the shift fails.
    func shift(
        pixel: Vec2,
        sampler: Sampler,
        params: ShiftMappingParams
    ) -> ShiftResult
    
    func initialize(scene: Scene)
}

struct ShiftMappingParams {
    let offsets: [Vec2]?
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

final class RandomSequenceReplay: ShiftMapping {
    unowned var scene: Scene!
    
    private var gradientOffsets: [Vec2] = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]

    func initialize(scene: Scene) {
        self.scene = scene
    }

    func shift(pixel: Vec2, sampler: Sampler, params: ShiftMappingParams) -> ShiftResult {
        if let forceOffsets = params.offsets {
            gradientOffsets = forceOffsets
        }
        let maxDepth = 16
        let minDepth = 0
        
        var li = ShiftResult()
        guard var main: RayState.Data = switch RayState.new(pixel: pixel, offset: .zero, scene: scene) {
            case .dead: nil
            case .connected(let data), .connectedRecently(let data), .fresh(let data): data
        } else {
            return li
        }
        
        var offsets = gradientOffsets.map { RayState.new(pixel: pixel, offset: $0, scene: scene) }
        
        var depth = 1
        while depth <= maxDepth && depth >= minDepth {
            offsets = offsets.map { $0.sanitized() }

            if main.its.hasEmission && depth == 1 {
                let frame = Frame(n: main.its.n)
                let wo = frame.toLocal(v: -main.ray.d)
                li.main += main.its.shape.light.L(p: main.its.p, n: main.its.n, uv: main.its.uv, wo: wo)
                // TODO Should we return early here
            } else if !main.its.hasEmission && !main.its.shape.material.hasDelta(uv: main.its.uv, p: main.its.p) {
                light(main: &main, offsets: offsets, li: &li, sampler: sampler) // Direct light sampling
            }
        
            // Sample material, or return current values if it fails
            guard let updated = bsdf(main: &main, offsets: offsets, li: &li, sampler: sampler) else { return li }
            offsets = updated
            depth += 1
        }
        return li
    }
    
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
        let mainContrib = main.throughput * mainBsdfEval * lightSample.L
        let mainGeometrySquaredLength = (main.its.p - lightSample.p).lengthSquared
        let mainGeometryCosLight = lightSample.n.dot(lightSample.wi)
        // Compute shift maps
        for (i, o) in offsets.enumerated() {
            let result: (shiftWeightDem: Float, shiftContrib: Color)
            switch o {
            case .dead: result = (mainWeightNum / (0.0001 + mainWeightDem), .zero)
            case .connected(let s), .connectedRecently(let s), .fresh(let s):
                guard !s.its.hasEmission else { result = (0, .zero); break }
                
                let ctx = LightSample.Context(p: s.its.p, n: s.its.n, ns: s.its.n)
                let frame = Frame(n: s.its.n)
                guard let shiftLightSample = scene.sample(context: ctx, s: rngLight) else { result = (0, .zero); break }

                let shiftEmmiterRadiance = shiftLightSample.L * (shiftLightSample.pdf / lightSample.pdf)
                let shiftDirectionOutLocal = frame.toLocal(v: shiftLightSample.wi).normalized()
                let shiftFrame = Frame(n: s.its.n)
                let shiftInLocal = shiftFrame.toLocal(v: -s.ray.d).normalized()
                let shiftBsdfValue = s.its.shape.material.evaluate(wo: shiftInLocal, wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                let shiftBsdfPdf = s.its.shape.material.pdf(wo: shiftInLocal, wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                let weightDem = s.pdf * (shiftLightSample.pdf + shiftBsdfPdf)
                let contrib = s.throughput * shiftBsdfValue * shiftEmmiterRadiance
                result = (weightDem, contrib)
            }
            
            let weight = mainWeightNum / (mainWeightDem + result.shiftWeightDem)
            assert(weight.isFinite)
            assert(weight >= 0 && weight <= 1)
            li.main += mainContrib * 0.5 * weight / lightSample.pdf
            li.radiances[i] += result.shiftContrib * 0.5 * weight / lightSample.pdf
            li.gradients[i] += (result.shiftContrib / lightSample.pdf - mainContrib / lightSample.pdf) * 0.5 * weight
        }
    }
    
    private func bsdf(main: inout RayState.Data, offsets: [RayState], li: inout ShiftResult, sampler: Sampler) -> [RayState]? {
        let frame = Frame(n: main.its.n)
        let wo = frame.toLocal(v: -main.ray.d).normalized()
        let seed = sampler.rng.state
        guard !main.its.hasEmission, let mainSampledBsdf = main.its.shape.material.sample(wo: wo, uv: main.its.uv, p: main.its.p, sample: sampler.next2()) else { return nil }
        
        let mainDirectionOutGlobal = frame.toWorld(v: mainSampledBsdf.wi).normalized()
        main.ray = Ray(origin: main.its.p, direction: mainDirectionOutGlobal)
        let mainPrevIts = main.its
        guard let newIts = scene.hit(r: main.ray) else { return nil }
        main.its = newIts
        
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
            let result: (weightDem: Float, contrib: Color, state: RayState)
            switch o {
            case .dead: result = (0, .zero, .dead)
            case .connected(let s), .fresh(let s), .connectedRecently(let s):
                let frame = Frame(n: s.its.n)
                let wo = frame.toLocal(v: -s.ray.d).normalized()
                sampler.rng.state = seed // Replay
                guard !s.its.hasEmission, let shiftSampledBsdf = s.its.shape.material.sample(wo: wo, uv: s.its.uv, p: s.its.p, sample: sampler.next2()) else { result = (0.0, .zero, .dead); break }
                
                let shiftDirectionOutGlobal = frame.toWorld(v: shiftSampledBsdf.wi).normalized()
                let newRay = Ray(origin: s.its.p, direction: shiftDirectionOutGlobal)
                let shiftPrevIts = main.its
                let shiftDirectionOutLocal = frame.toLocal(v: shiftDirectionOutGlobal).normalized()
                let shiftDirectionInLocal = frame.toLocal(v: -s.ray.d)
                let shiftBsdfValue = s.its.shape.material.evaluate(wo: shiftDirectionInLocal, wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                let shiftBsdfPdf = s.its.shape.material.pdf(wo: shiftDirectionInLocal, wi: shiftDirectionOutLocal, uv: s.its.uv, p: s.its.p)
                let newThroughput = s.throughput * shiftBsdfValue / shiftSampledBsdf.pdf
                let newPdf = s.pdf * shiftBsdfPdf
                
                let bounceLight: Light?  = if s.its.hasEmission { s.its.shape.light } else { nil }
                let bounceLightPdf: Float = bounceLight.map {
                    let ctx = LightSample.Context(p: mainPrevIts.p, n: mainPrevIts.n, ns: mainPrevIts.n)
                    return $0.pdfLi(context: ctx, y: main.its.p)
                } ?? 0
                let bounceLightRadiance: Color = bounceLight.map {
                    let frame = Frame(n: main.its.n)
                    let wo = frame.toLocal(v: -main.ray.d).normalized()
                    return $0.L(p: main.its.p, n: main.its.n, uv: main.its.uv, wo: wo)
                } ?? .zero
                
                
                let shiftLightPdf: Float = bounceLight.map { _ in
                    guard bounceLightPdf != 0 else { return 0 }
                    let ctx = LightSample.Context(p: s.its.p, n: s.its.n, ns: s.its.n)
                    return s.its.shape.light.pdfLi(context: ctx, y: s.its.p)
                } ?? 0
                
                let shiftWeightDem = s.pdf * (shiftBsdfPdf + shiftLightPdf)
                let shiftContrib = newThroughput * bounceLightRadiance
                
                result = (
                    shiftWeightDem,
                    shiftContrib,
                    .connectedRecently(data: RayState.Data(pdf: newPdf, ray: newRay, its: newIts, throughput: newThroughput))
                )
            }
            
            let lightDem = bounceLightPdf == 0 ? 1 : bounceLightPdf
            let mainWeightDem = mainSampledBsdf.pdf + bounceLightPdf
            let weight = mainSampledBsdf.pdf / (mainWeightDem + result.weightDem + 0.00001)
            assert(weight.isFinite)
            assert(weight >= 0 && weight <= 1)
            li.main += mainBsdfContrib * 0.5 * weight / lightDem
            li.radiances[i] += result.contrib * 0.5 * weight / lightDem
            li.gradients[i] += (result.contrib / lightDem - mainBsdfContrib / lightDem) * 0.5 * weight
            return result.state
        }
    }
}

final class PathReconnection: ShiftMapping {
    struct Stats {
        var successfulConnections: Int = 0
        var failedConnections: Int = 0
        var total: Int { successfulConnections + failedConnections }
    }

    unowned var scene: Scene!

    var stats = Stats()

    private var gradientOffsets: [Vec2] = [-Vec2(1, 0), Vec2(1, 0), -Vec2(0, 1), Vec2(0, 1)]

    func initialize(scene: Scene) {
        self.scene = scene
        
    }
    
    func shift(pixel: Vec2, sampler: Sampler, params: ShiftMappingParams) -> ShiftResult {
        if let forceOffsets = params.offsets {
            gradientOffsets = forceOffsets
        }

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
        
        var offsets = gradientOffsets.map { RayState.new(pixel: pixel, offset: $0, scene: scene) }
        
        var depth = 1
        while depth <= maxDepth && depth >= minDepth {
            offsets = offsets.map { $0.sanitized() }

            if main.its.hasEmission && depth == 1 {
                let frame = Frame(n: main.its.n)
                let wo = frame.toLocal(v: -main.ray.d)
                li.main += main.its.shape.light.L(p: main.its.p, n: main.its.n, uv: main.its.uv, wo: wo)
                // TODO Should we return early here
            } else if !main.its.hasEmission && !main.its.shape.material.hasDelta(uv: main.its.uv, p: main.its.p) {
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
        let mainContrib = main.throughput * mainBsdfEval * lightSample.L
        let mainGeometrySquaredLength = (main.its.p - lightSample.p).lengthSquared
        let mainGeometryCosLight = lightSample.n.dot(lightSample.wi)
        // Compute shift maps
        for (i, o) in offsets.enumerated() {
            let result: (shiftWeightDem: Float, shiftContrib: Color)
            switch o {
            case .dead: result = (mainWeightNum / (0.0001 + mainWeightDem), .zero)
            case .connected(let s):
                let dem = (s.pdf / main.pdf) * (lightSample.pdf + mainBsdfPdf)
                let contrib = s.throughput * mainBsdfEval * lightSample.L
                result = (dem, contrib)
            case .connectedRecently(let s):
                let shiftDirectionInGlobal = (s.its.p - main.its.p).normalized()
                let shiftDirectionInLocal = mainFrame.toLocal(v: shiftDirectionInGlobal).normalized()
                guard shiftDirectionInLocal.z > 0 else { result = (0.0, Color.zero); break }

                let shiftBsdfPdf = main.its.shape.material.pdf(wo: shiftDirectionInLocal, wi: mainLightOutLocal, uv: s.its.uv, p: s.its.p)
                let shiftBsdfValue = main.its.shape.material.evaluate(wo: shiftDirectionInLocal, wi: mainLightOutLocal, uv: s.its.uv, p: s.its.p)
                let weightDem = (s.pdf / main.pdf) * (lightSample.pdf + shiftBsdfPdf)
                let contrib = s.throughput * shiftBsdfValue * lightSample.L
                result = (weightDem, contrib)
            case .fresh(let s):
                guard !s.its.hasEmission else { result = (0, .zero); break }
                
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
                let contrib = jacobian * s.throughput * shiftBsdfValue * shiftEmmiterRadiance
                result = (weightDem, contrib)
            }
            
            let weight = mainWeightNum / (mainWeightDem + result.shiftWeightDem)
            assert(weight.isFinite)
            assert(weight >= 0 && weight <= 1)
            li.main += mainContrib * weight / lightSample.pdf
            li.radiances[i] += result.shiftContrib * weight / lightSample.pdf
            li.gradients[i] += (result.shiftContrib / lightSample.pdf - mainContrib / lightSample.pdf) * weight
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
            let result: (weightDem: Float, contrib: Color, state: RayState)
            switch o {
            case .dead: result = (0, .zero, .dead)
            case .connected(let s):
                let newThroughput = s.throughput * mainSampledBsdf.weight
                let newPdf = s.pdf * mainSampledBsdf.pdf
                let shiftWeightDem = (s.pdf / mainPdfPrev) * (mainSampledBsdf.pdf + bounceLightPdf)
                let shiftContrib = newThroughput * bounceLightRadiance
                result = (
                    shiftWeightDem,
                    shiftContrib,
                    .connected(data: RayState.Data(pdf: newPdf, ray: s.ray, its: s.its, throughput: newThroughput))
                )
            case .connectedRecently(let s):
                guard mainPrevIts.shape.material.hasDelta(uv: mainPrevIts.uv, p: mainPrevIts.p) == false else { result = (0.0, .zero, .dead); break }
                
                let frame = Frame(n: mainPrevIts.n)
                let shiftDirectionInGlobal = (s.its.p - main.ray.o).normalized()
                let shiftDirectionInLocal = frame.toLocal(v: shiftDirectionInGlobal).normalized()
                guard shiftDirectionInLocal.z > 0 else { result = (0.0, .zero, .dead); break }
                
                let shiftBsdfPdf = mainPrevIts.shape.material.pdf(wo: shiftDirectionInLocal, wi: mainSampledBsdf.wi, uv: mainPrevIts.uv, p: mainPrevIts.p)
                let shiftBsdfValue = mainPrevIts.shape.material.evaluate(wo: shiftDirectionInLocal, wi: mainSampledBsdf.wi, uv: mainPrevIts.uv, p: mainPrevIts.p)
                let newThroughput = s.throughput * (shiftBsdfValue / mainSampledBsdf.pdf)
                let newPdf = s.pdf * shiftBsdfPdf
                let shiftWeightDem = (s.pdf / mainPdfPrev) * (shiftBsdfPdf + bounceLightPdf)
                let shiftContrib = newThroughput * bounceLightRadiance
                result = (
                    shiftWeightDem,
                    shiftContrib,
                    .connected(data: RayState.Data(pdf: newPdf, ray: s.ray, its: s.its, throughput: newThroughput))
                )
            case .fresh(let s):
                guard !s.its.hasEmission && s.its.p.visible(from: main.its.p, within: scene) else { result = (0.0, .zero, .dead); break }
                
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
                let shiftLightPdf: Float = bounceLight.map { _ in
                    guard bounceLightPdf != 0 else { return 0 }
                    let ctx = LightSample.Context(p: s.its.p, n: s.its.n, ns: s.its.n)
                    return main.its.shape.light.pdfLi(context: ctx, y: main.its.p)
                } ?? 0
                
                let shiftWeightDem = (s.pdf / mainPdfPrev) * (shiftBsdfPdf + shiftLightPdf)
                let shiftContrib = newThroughput * bounceLightRadiance
                result = (
                    shiftWeightDem,
                    shiftContrib,
                    .connectedRecently(data: RayState.Data(pdf: newPdf, ray: s.ray, its: s.its, throughput: newThroughput))
                )
            }
            
            let lightDem = bounceLightPdf == 0 ? 1 : bounceLightPdf
            let mainWeightDem = mainSampledBsdf.pdf + bounceLightPdf
            let weight = mainSampledBsdf.pdf / (mainWeightDem + result.weightDem + 0.00001)
            assert(weight.isFinite)
            assert(weight >= 0 && weight <= 1)
            li.main += mainBsdfContrib * weight / lightDem
            li.radiances[i] += result.contrib * weight / lightDem
            li.gradients[i] += (result.contrib / lightDem - mainBsdfContrib / lightDem) * weight
            return result.state
        }
    }
}

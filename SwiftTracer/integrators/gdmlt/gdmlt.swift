//
//  gdmlt.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-07.
//

import Foundation
import Progress

/// Gradient domain metropolis light transport integrator
final class GdmltIntegrator: Integrator {
    enum CodingKeys: String, CodingKey {
        case shiftMapping
        case maxDepth
        case minDepth
    }
    
    private let maxReconstructIterations: Int
    private let maxDepth: Int
    private let minDepth: Int
    private let mapper: ShiftMapping

    init(mapper: ShiftMapping, maxReconstructIterations: Int, minDepth: Int = 0, maxDepth: Int = 16) {
        self.mapper = mapper
        self.maxReconstructIterations = maxReconstructIterations
        self.minDepth = minDepth
        self.maxDepth = maxDepth
    }

    func render(scene: Scene, sampler: any Sampler) -> Array2d<Color> {
        let result: GradientDomainResult = render(scene: scene, sampler: sampler)
        return result.img
    }
}

extension GdmltIntegrator: SamplerIntegrator {
    func preprocess(scene: Scene, sampler: any Sampler) {
        // no op
    }
    
    
    /// Evaluates direct lighting on a given intersection
    private func light(wo: Vec3, scene: Scene, frame: Frame, intersection: Intersection, s: Vec2) -> Color {
        let ctx = LightSample.Context(p: intersection.p, n: intersection.n, ns: intersection.n)
        guard let lightSample = scene.sample(context: ctx, s: s) else { return .zero }
        let localWi = frame.toLocal(v: lightSample.wi).normalized()
        let pdf = intersection.shape.material.pdf(wo: wo, wi: localWi, uv: intersection.uv, p: intersection.p)
        let eval = intersection.shape.material.evaluate(wo: wo, wi: localWi, uv: intersection.uv, p: intersection.p)
        let weight = lightSample.pdf / (pdf + lightSample.pdf)
        
        return (weight * eval / lightSample.pdf) * lightSample.L
    }

    /// Recursively traces rays using MIS
    private func trace(intersection: Intersection?, ray: Ray, path: Path, scene: Scene, sampler: Sampler, depth: Int) -> Color {
        guard ray.d.length.isFinite else { return .zero }
        guard let intersection = intersection else { return scene.background }
        var contribution = Color()
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        let s = sampler.next2()
        
        guard !intersection.hasEmission else {
            path.add(vertex: LightVertex(intersection: intersection))
            return intersection.shape.light.L(p: intersection.p, n: intersection.n, uv: intersection.uv, wo: wo)
        }

        // MIS Emitter
        contribution += light(wo: wo, scene: scene, frame: frame, intersection: intersection, s: s)

        // MIS Material
        guard let direction = intersection.shape.material.sample(wo: wo, uv: intersection.uv, p: intersection.p, sample: s) else {
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

        path.add(vertex: SurfaceVertex(intersection: intersection), weight: direction.weight, contribution: contribution)
        return depth == maxDepth || (its?.hasEmission == true && depth >= minDepth)
            ? contribution
            : contribution + trace(intersection: its, ray: newRay, path: path, scene: scene, sampler: sampler, depth: depth + 1) * bsdfWeight
    }
    
    private func defaultStop(path: Path) -> Bool {
        return false
    }
    
    func li(ray: Ray, scene: Scene, sampler: any Sampler) -> Color {
        return li(ray: ray, scene: scene, sampler: sampler, stop: defaultStop).contrib
    }
    
    func li(pixel: Vec2, scene: Scene, sampler: Sampler) -> Color {
        return li(pixel: pixel, scene: scene, sampler: sampler, stop: defaultStop).contrib
    }
}

extension GdmltIntegrator: PathSpaceIntegrator {
    func li(ray: Ray, scene: Scene, sampler: any Sampler, stop: (Path) -> Bool) -> (contrib: Color, path: Path) {
        let root = CameraVertex()
        let path = Path.start(at: root)
        
        guard let intersection = scene.hit(r: ray) else { return (scene.background, path) }
        let frame = Frame(n: intersection.n)
        let wo = frame.toLocal(v: -ray.d).normalized()
        if intersection.hasEmission {
            // TODO Figure out intersection and wo geometry
            path.add(vertex: LightVertex(intersection: intersection))
            return (intersection.shape.light.L(p: intersection.p, n: intersection.n, uv: intersection.uv, wo: wo), path)
        } else {
            return (trace(intersection: intersection, ray: ray, path: path, scene: scene, sampler: sampler, depth: 0), path)
        }
    }

    func li(pixel: Vec2, scene: Scene, sampler: any Sampler, stop: (Path) -> Bool) -> (contrib: Color, path: Path) {
        let ray = scene.camera.createRay(from: pixel)
        return li(ray: ray, scene: scene, sampler: sampler, stop: stop)
    }
}
                                
extension GdmltIntegrator: GradientDomainIntegrator {
    internal struct Block {
        let position: Vec2
        let size: Vec2
        var image: Array2d<Color>
        var dxGradients: Array2d<Color>
        var dyGradients: Array2d<Color>
        
        mutating func update(img: Array2d<Color>, dx: Array2d<Color>, dy: Array2d<Color>) {
            self.image = img
            self.dxGradients = dx
            self.dyGradients = dy
        }
    }
    
    func render(scene: Scene, sampler: any Sampler) -> GradientDomainResult {
        print("Integrator preprocessing ...")
        preprocess(scene: scene, sampler: sampler)
        
        print("Rendering ...")
        let img = Array2d<Color>(x: Int(scene.camera.resolution.x), y: Int(scene.camera.resolution.y), value: .zero)
        let dxGradients = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        let dyGradients = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        mapper.initialize(sampler: sampler, integrator: self, scene: scene)

        let gcd = DispatchGroup()
        gcd.enter()
        Task {
            defer { gcd.leave() }
            var progress = ProgressBar(count: Int(scene.camera.resolution.x) / 32 * Int(scene.camera.resolution.y) / 32, printer: Printer())
            let blocks = await renderBlocks(scene: scene, mapper: mapper) {
                progress.next()
            }
            
            return blocks.assemble(into: img, dx: dxGradients, dy: dyGradients)
        }
        
        gcd.wait()
        
        print("Reconstructing with dx and dy ...")
        return GradientDomainResult(
            img: reconstruct(image: img, dxGradients: dxGradients, dyGradients: dyGradients),
            dx: dxGradients.transformed { $0.abs },
            dy: dyGradients.transformed { $0.abs }
        )
        
    }
    
    private func renderBlocks(blockSize: Int = 32, scene: Scene, mapper: ShiftMapping, increment: @escaping () -> Void) async -> [Block] {
        return await withTaskGroup(of: Block.self) { group in
            for x in stride(from: 0, to: Int(scene.camera.resolution.x), by: blockSize) {
                for y in stride(from: 0, to: Int(scene.camera.resolution.y), by: blockSize) {
                    let size = Vec2(
                        min(scene.camera.resolution.x - Float(x), Float(blockSize)),
                        min(scene.camera.resolution.y - Float(y), Float(blockSize))
                    )
                    
                    group.addTask {
                        increment()
                        return self.renderBlock(scene: scene, size: size, x: x, y: y, mapper: mapper)
                    }
                }
            }

            var blocks: [Block] = []
            for await block in group {
                blocks.append(block)
            }
            
            return blocks
        }
    }

    private func renderBlock(scene: Scene, size: Vec2, x: Int, y: Int, mapper: ShiftMapping) -> Block {
        let img = Array2d(x: Int(size.x), y: Int(size.y), value: Color())
        let dxGradients = Array2d<Color>(x: img.xSize + 1, y: img.ySize + 1, value: .zero)
        let dyGradients = Array2d<Color>(x: img.xSize + 1, y: img.ySize + 1, value: .zero)
        var block = Block(
            position: Vec2(Float(x), Float(y)),
            size: size,
            image: img,
            dxGradients: dxGradients,
            dyGradients: dyGradients
        )

        for _ in 0 ..< mapper.sampler.nbSamples {
            for lx in 0 ..< Int(block.size.x) {
                for ly in 0 ..< Int(block.size.y) {
                    let x = lx + Int(block.position.x)
                    let y = ly + Int(block.position.y)

                    let originalSeed = mapper.sampler.rng.state
                    let base = Vec2(Float(x), Float(y)) + mapper.sampler.next2()
                    let pixel = li(pixel: base, scene: scene, sampler: mapper.sampler)
                    img[lx, ly] += pixel
                    
                    // TODO Figure out a way to build appripriately for path reconnection
                    let params = ShiftMapParams(seed: originalSeed)
                    let left = mapper.shift(pixel: base, offset: -Vec2(1, 0), params: params)
                    let right = mapper.shift(pixel: base, offset: Vec2(1, 0), params: params)
                    let top = mapper.shift(pixel: base, offset: -Vec2(0, 1), params: params)
                    let bottom = mapper.shift(pixel: base, offset: Vec2(0, 1), params: params)
                    
//                    if let l = left {
//                        let alpha: Float = dxGradients[lx, ly+1] == .zero
//                            ? 1.0
//                            : 0.5
                    dxGradients[lx, ly+1] += 0.5 * (pixel - (left ?? .zero))
//                    }
//                    if let t = top {
//                        let alpha: Float = dyGradients[lx+1, ly] == .zero
//                            ? 1.0
//                            : 0.5
                        dyGradients[lx+1, ly] += 0.5 * (pixel - (top ?? .zero))
//                    }
//                    if let r = right {
//                        let alpha: Float = y+1 >= Int(scene.camera.resolution.x)
//                            ? 1.0
//                            : 0.5
                        dxGradients[lx+1, ly+1] += 0.5 * ((right ?? .zero) - pixel)
//                    }
//                    if let b = bottom {
//                        let alpha: Float = y+1 >= Int(scene.camera.resolution.y)
//                            ? 1.0
//                            : 0.5
                        dyGradients[lx+1, ly+1] += 0.5 * ((bottom ?? .zero) - pixel)
//                    }
                }
            }
        }
        
        let scaleFactor: Float = 1.0 / Float(mapper.sampler.nbSamples)
        img.scale(by: scaleFactor)
        dxGradients.scale(by: scaleFactor)
        dyGradients.scale(by: scaleFactor)
        block.update(img: img, dx: dxGradients, dy: dyGradients)
        return block
    }
    
    private func reconstruct(image img: Array2d<Color>, dxGradients: Array2d<Color>, dyGradients: Array2d<Color>) -> Array2d<Color> {
        let j = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        var final = Array2d<Color>(copy: img)
        let max: (x: Int, y: Int) = (x: Int(img.xSize - 1), y: Int(img.ySize - 1))
        for _ in 0 ..< maxReconstructIterations {
            for x in 0 ..< img.xSize {
                for y in 0 ..< img.ySize {
                    var value = final[x, y]
                    
                    if x != 0 { value += final[x - 1, y] + dxGradients[x - 1, y] }
                    if y != 0 { value += final[x, y - 1] + dyGradients[x, y - 1] }
                    if x != max.x { value += final[x + 1, y] }
                    value -= dxGradients[x, y]
                    if y != max.y { value += final[x, y + 1] }
                    value -= dyGradients[x, y]
                    j[x, y] = value / 5
                }
            }
            
            final = j
        }
        return final
    }
}

private extension [GdmltIntegrator.Block] {
    func assemble(into image: Array2d<Color>, dx: Array2d<Color>, dy: Array2d<Color>) -> GradientDomainResult {
        for block in self {
            for lx in (0 ..< Int(block.size.x)) {
                for ly in (0 ..< Int(block.size.y)) {
                    let (x, y): (Int, Int) = (lx + Int(block.position.x), ly + Int(block.position.y))
                    image[x, y] = block.image[lx, ly]
                    if lx == 0 && x != 0 { dx[x - 1, y] += block.dxGradients[lx, ly] }
                    if ly == 0 && y != 0 { dy[x, y - 1] += block.dyGradients[lx, ly] }
                    dx[x, y] += block.dxGradients[lx+1, ly+1]
                    dy[x, y] += block.dyGradients[lx+1, ly+1]
                }
            }
        }
        
        return GradientDomainResult(img: image, dx: dx, dy: dy)
    }
}

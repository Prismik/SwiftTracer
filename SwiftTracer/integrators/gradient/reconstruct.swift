//
//  reconstruct.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-20.
//

enum ReconstructionType: String, Decodable {
    case iterative
}

struct AnyReconstruction: Decodable {
    enum CodingKeys: String, CodingKey {
        case type
        case maxIterations
    }
    
    let wrapped: Reconstructing
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ReconstructionType.self, forKey: .type)
        switch type {
        case .iterative:
            let maxIteration = try container.decodeIfPresent(Int.self, forKey: .maxIterations) ?? 40
            wrapped = IterativeReconstruction(maxIterations: maxIteration)
        }
    }
}

protocol Reconstructing {
    func reconstruct(gradientDomainResult: GradientDomainResult) -> PixelBuffer
}

struct IterativeReconstruction: Reconstructing {
    let maxIterations: Int
    let sanitize: Bool = true

    func reconstruct(gradientDomainResult: GradientDomainResult) -> PixelBuffer {
        let img = gradientDomainResult.primal
        let dx: PixelBuffer
        let dy: PixelBuffer
        let bounds: (x: Int, y: Int) = (x: Int(img.width - 1), y: Int(img.height - 1))
        if sanitize {
            let sdx = PixelBuffer(copy: gradientDomainResult.dx)
            let sdy = PixelBuffer(copy: gradientDomainResult.dy)
            for y in 0 ..< img.height {
                for x in 0 ..< img.width {
                    var dxNeighbours: [Color] = []
                    var dyNeighbours: [Color] = []
                    for (nx, ny) in [(-1, -1), (1, 1), (1, -1), (-1, 1), (1, 0), (0, 1), (-1, 0), (0, -1)] {
                        if (0 ... bounds.x).contains(x + nx) && (0 ... bounds.y).contains(y + ny) {
                            dxNeighbours.append(gradientDomainResult.dx[x + nx, y + ny])
                            dyNeighbours.append(gradientDomainResult.dy[x + nx, y + ny])
                        }
                    }
                    
                    let dxLuminance: Float = dxNeighbours.reduce(into: 0.0) { partialResult, c in
                        partialResult += c.abs.luminance
                    }
                    
                    var n = 1
                    let dxColor = dxNeighbours.reduce(into: Color()) { partialResult, c in
                        let suspicious = c.abs.x > 20 || c.abs.y > 20 || c.abs.z > 20
                        partialResult += suspicious ? partialResult / Float(n) : c
                        n += 1
                    }
                    
                    let dyLuminance: Float = dyNeighbours.reduce(into: 0.0) { partialResult, c in
                        partialResult += c.abs.luminance
                    }
                    
                    n = 1
                    let dyColor = dyNeighbours.reduce(into: Color()) { partialResult, c in
                        let suspicious = c.abs.x > 20 || c.abs.y > 20 || c.abs.z > 20
                        partialResult += suspicious ? partialResult / Float(n) : c
                        n += 1
                    }
                    
                    // Check for kernel condition
                    let dxTarget = gradientDomainResult.dx[x, y]
                    let dxSuspicious = dxTarget.abs.x > 20 || dxTarget.abs.y > 20 || dxTarget.abs.z > 20
                    if dxSuspicious && gradientDomainResult.dx[x, y].abs.luminance > dxLuminance / Float(dxNeighbours.count) {
                        sdx[x, y] = dxColor / Float(dxNeighbours.count)
                    }
                    
                    let dyTarget = gradientDomainResult.dy[x, y]
                    let dySuspicious = dyTarget.abs.x > 20 || dyTarget.abs.y > 20 || dyTarget.abs.z > 20
                    if dySuspicious && gradientDomainResult.dy[x, y].abs.luminance > dyLuminance / Float(dyNeighbours.count) {
                        sdy[x, y] = dyColor / Float(dyNeighbours.count)
                    }
                }
            }
            dx = sdx
            dy = sdy
            
            guard Image(encoding: .exr).write(img: dx.transformed { $0.abs }, to: "dx-sanitized.exr") else {
                fatalError("Error in saving convergence image")
            }
            
            guard Image(encoding: .exr).write(img: dy.transformed { $0.abs }, to: "dy-sanitized.exr") else {
                fatalError("Error in saving convergence image")
            }
        } else {
            dx = gradientDomainResult.dx
            dy = gradientDomainResult.dy
        }

        let j = PixelBuffer(width: img.width, height: img.height, value: .zero)
        var final = PixelBuffer(copy: img)
        
        for _ in 0 ..< maxIterations {
            for y in 0 ..< img.height {
                for x in 0 ..< img.width {
                    var value = final[x, y]
                    var w: Float = 1
                    if x != 0 {
                        value += final[x - 1, y] + dx[x - 1, y]
                        w += 1
                    }
                    if y != 0 {
                        value += final[x, y - 1] + dy[x, y - 1]
                        w += 1
                    }
                    
                    if x != bounds.x {
                        value += final[x + 1, y] - dx[x, y]
                        w += 1
                    }
                    if y != bounds.y {
                        value += final[x, y + 1] - dy[x, y]
                        w += 1
                    }
                    j[x, y] = value / w
                }
            }
            
            final = j
        }
        
        final.merge(with: gradientDomainResult.directLight)
        
        // Prevents very bad negative values caused by overly large gradients
        return final.transformed {
            let r = max(0.0, $0.x)
            let g = max(0.0, $0.y)
            let b = max(0.0, $0.z)
            return Color(r, g, b)
        }
    }
}

struct WeightedReconstruction: Reconstructing {
    let maxIterations: Int

    private enum Metric {
        case mean
        case variance
        
        func compute(x: Int, y: Int) -> Color {
            return switch self {
            case .mean: .zero
            case .variance: .zero
            }
            
        }
    }

    func reconstruct(gradientDomainResult gdr: GradientDomainResult) -> PixelBuffer {
        let img = gdr.primal
        let dx = gdr.dx
        let dy = gdr.dy
        let j = PixelBuffer(width: img.width, height: img.height, value: .zero)
        var final = PixelBuffer(copy: img)
        let max: (x: Int, y: Int) = (x: Int(img.width - 1), y: Int(img.height - 1))
        
        let avgAndVariance = compute(metrics: [.mean, .variance], on: gdr)

        for y in 0 ..< img.height {
            for x in 0 ..< img.width {
                
            }
        }
        return img
    }
    
    private func compute(metrics: Set<Metric>, on gdr: GradientDomainResult) -> [Metric: GradientDomainResult] {
        
        var result: [Metric: GradientDomainResult] = [:]
        for image in [gdr.primal, gdr.dx, gdr.dy] {
            
        }
        return result
    }
}

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
    
    func reconstruct(gradientDomainResult: GradientDomainResult) -> PixelBuffer {
        let img = gradientDomainResult.primal
        let dx = gradientDomainResult.dx
        let dy = gradientDomainResult.dy
        let j = PixelBuffer(width: img.width, height: img.height, value: .zero)
        var final = PixelBuffer(copy: img)
        let max: (x: Int, y: Int) = (x: Int(img.width - 1), y: Int(img.height - 1))
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
                    
                    if x != max.x {
                        value += final[x + 1, y] - dx[x, y]
                        w += 1
                    }
                    if y != max.y {
                        value += final[x, y + 1] - dy[x, y]
                        w += 1
                    }
                    j[x, y] = value / w
                }
            }
            
            final = j
        }
        
        final.merge(with: gradientDomainResult.directLight)
        return final
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

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
    func reconstruct(gradientDomainResult: GradientDomainResult) -> Array2d<Color>
}

struct IterativeReconstruction: Reconstructing {
    let maxIterations: Int
    
    func reconstruct(gradientDomainResult: GradientDomainResult) -> Array2d<Color> {
        let img = gradientDomainResult.primal
        let dx = gradientDomainResult.dx
        let dy = gradientDomainResult.dy
        let j = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        var final = Array2d<Color>(copy: img)
        let max: (x: Int, y: Int) = (x: Int(img.xSize - 1), y: Int(img.ySize - 1))
        for _ in 0 ..< maxIterations {
            for y in 0 ..< img.ySize {
                for x in 0 ..< img.xSize {
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


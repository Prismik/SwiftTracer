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
    func reconstruct(image img: Array2d<Color>, dx dxGradients: Array2d<Color>, dy dyGradients: Array2d<Color>) -> Array2d<Color>
}

struct IterativeReconstruction: Reconstructing {
    let maxIterations: Int
    
    func reconstruct(image img: Array2d<Color>, dx dxGradients: Array2d<Color>, dy dyGradients: Array2d<Color>) -> Array2d<Color> {
        let j = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        var final = Array2d<Color>(copy: img)
        let max: (x: Int, y: Int) = (x: Int(img.xSize - 1), y: Int(img.ySize - 1))
        for _ in 0 ..< maxIterations {
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

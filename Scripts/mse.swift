//
//  mse.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-21.
//

/// Contains the computations for the mean squared error between to images.
/// > Important: The size of both `original` and `compared` must be the same.
struct MeanSquaredError {
    let original: PixelBuffer
    let compared: PixelBuffer
    
    private let max: Float = 255
    func run() -> Void {
        let result = eval()
        print("Mean Squared Error => \(result)")
    }
    
    func eval() -> Float {
        guard original.width == compared.width && original.height == compared.height else { fatalError("Cannot compute MSE of differently sized images") }
        
        let squaredErrorSum: Float = original.enumerated().reduce(into: 0) { acc, pair in
            let (i, o) = pair
            let delta = o * max - compared[i] * max
            let squared = delta * delta
            acc += (squared.x + squared.y + squared.z) / 3
        }

        let result = squaredErrorSum / Float(original.size)
        return result
    }
}

//
//  psnr.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-21.
//

import Foundation

struct PeakSignalToNoiseRatio {
    let original: PixelBuffer
    let compared: PixelBuffer
    
    private let max: Float = 255

    func run() -> Void {
        let mse = MeanSquaredError(original: original, compared: compared).eval()
        let result: Float = 20 * log10(max) - 10 * log10(mse)
        print(String(format:"PSNR => %.2f dB", result))
    }
}

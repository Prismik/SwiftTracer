//
//  scripts.swift
//  scripts
//
//  Created by Francis Beauchamp on 2024-10-10.
//

import Foundation
import ArgumentParser

@main
struct Scripts: ParsableCommand {
    @Argument(help: "The name for the image to compute gradients from.")
    var input: String
    
    mutating func run() throws {
        let input = input
        Gradients.compute(from: input)
    }
}

enum Gradients {
    static func compute(from filename: String) {
        guard let img = Image(filename: filename)?.read() else { fatalError("Could not read image") }
        let dx = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        let dy = Array2d<Color>(x: img.xSize, y: img.ySize, value: .zero)
        for x in 0 ..< img.xSize {
            for y in 0 ..< img.ySize {
                let base = img[x, y]
                let left: Color = x == 0
                    ? Color()
                    : img[x - 1, y]
                let right: Color = x == img.xSize - 1
                    ? Color()
                    : img[x + 1, y]
                let top: Color = y == 0
                    ? Color()
                    : img[x, y - 1]
                let bottom: Color = y == img.ySize - 1
                    ? Color()
                    : img[x, y + 1]
                
                if x != 0 { dx[x - 1, y] += 0.5 * (base - left) }
                if y != 0 { dy[x, y - 1] += 0.5 * (base - top) }
                dx[x, y] += 0.5 * (right - base)
                dy[x, y] += 0.5 * (bottom - base)
            }
        }
        
        let dxImage = Image(array: dx.transformed { $0.abs })
        _ = dxImage.write(to: "gradients-dx.png")
        let dyImage = Image(array: dy.transformed { $0.abs })
        _ = dyImage.write(to: "gradients-dy.png")
    }
}

//
//  gradients.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-21.
//


struct Gradients {
    let image: Array2d<Color>
    let outputDirectory: String

    func run() {
        let img = image
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
        _ = dxImage.write(to: "gradients-dx.png", directory: outputDirectory)
        let dyImage = Image(array: dy.transformed { $0.abs })
        _ = dyImage.write(to: "gradients-dy.png", directory: outputDirectory)
        
        print("Gradient images saved in \(outputDirectory)/gradients-dx.png and \(outputDirectory)/gradients-dy.png.")
    }
}

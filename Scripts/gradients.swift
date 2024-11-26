//
//  gradients.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-21.
//


struct Gradients {
    let image: PixelBuffer
    let outputDirectory: String

    func run() {
        let img = image
        let dx = PixelBuffer(width: img.width, height: img.height, value: .zero)
        let dy = PixelBuffer(width: img.width, height: img.height, value: .zero)
        for x in 0 ..< img.width {
            for y in 0 ..< img.height {
                let base = img[x, y]
                let left: Color = x == 0
                    ? Color()
                    : img[x - 1, y]
                let right: Color = x == img.width - 1
                    ? Color()
                    : img[x + 1, y]
                let top: Color = y == 0
                    ? Color()
                    : img[x, y - 1]
                let bottom: Color = y == img.height - 1
                    ? Color()
                    : img[x, y + 1]
                
                if x != 0 { dx[x - 1, y] += 0.5 * (base - left) }
                if y != 0 { dy[x, y - 1] += 0.5 * (base - top) }
                dx[x, y] += 0.5 * (right - base)
                dy[x, y] += 0.5 * (bottom - base)
            }
        }
        
        _ = Image(encoding: .png).write(img: dx.transformed { $0.abs }, to: "gradients-dx.png")
        _ = Image(encoding: .png).write(img: dy.transformed { $0.abs }, to: "gradients-dy.png")
        
        print("Gradient images saved in \(outputDirectory)/gradients-dx.png and \(outputDirectory)/gradients-dy.png.")
    }
}

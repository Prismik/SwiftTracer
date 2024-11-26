//
//  heatmap.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-11-22.
//

import Foundation

struct Heatmap {
    let floor: Color
    let ceil: Color
    
    private var maxValue = 0
    private var map: [Vec2: Int] = [:]
    private let lock = NSLock()

    init(floor: Color, ceil: Color) {
        self.floor = floor
        self.ceil = ceil
    }
    
    mutating func increment(at position: Vec2) {
        lock.withLock {
            let rounded = Vec2(Float(Int(position.x)), Float(Int(position.y)))
            map[rounded, default: 0] += 1
            maxValue = max(maxValue, map[rounded, default: 0])
        }
    }

    func generate(width: Int, height: Int) -> PixelBuffer {
        let buffer = PixelBuffer(width: width, height: height, value: floor)
        for (key, value) in map {
            let normalized = Float(value) / Float(maxValue)
            buffer[Int(key.x), Int(key.y)] = color(for: normalized)
        }
        
        return buffer
    }

    private func color(for value: Float) -> Color {
        (self.ceil - self.floor) * value + self.floor
    }
}

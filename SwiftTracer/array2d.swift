//
//  array2d.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import Foundation

struct TwoDimensionalIterator<T>: IteratorProtocol {
    var x: Int = 0
    var y: Int = 0
    
    private let array: Array2d<T>
    
    init(_ array: Array2d<T>) {
        self.array = array
    }

    mutating func next() -> T? {
        guard y < array.ySize && x < array.xSize else { return nil }
        let (cx, cy) = (x, y)
        let next = (x + 1) % array.xSize
        if next == 0 {
            y += 1
        }
        
        x = next
        
        return array.get(cx, cy)
    }
}

/// Two-dimensional array represented as a one dimensional array
class Array2d<T> {
    private(set) var xSize: Int
    private(set) var ySize: Int

    var size: Int { xSize * ySize }

    private var storage: [T]

    init() {
        self.xSize = 0
        self.ySize = 0
        self.storage = []
    }
    
    init(copy: Array2d<T>) {
        self.xSize = copy.xSize
        self.ySize = copy.ySize
        self.storage = copy.storage
    }
    
    init(x: Int, y: Int, value: T) {
        self.xSize = x
        self.ySize = y
        self.storage = Array(repeating: value, count: x * y)
    }
    
    func get(_ x: Int, _ y: Int) -> T {
        return storage[index(x, y)]
    }
    
    func set(value: T, _ x: Int, _ y: Int) {
        storage[index(x, y)] = value
    }

    func flipVertically() {
        let copy = Array2d(copy: self)
        for (i, item) in self.enumerated() {
            let (x, y) = index2d(i)
            copy.set(value: item, x, ySize - 1 -  y)
        }
        
        self.storage = copy.storage
    }

    func debug() {
        print(storage)
    }

    private func index(_ x: Int, _ y: Int) -> Int {
        return y * xSize + x
    }
    
    private func index2d(_ i: Int) -> (Int, Int) {
        return (i % xSize, i / xSize)
    }
}

extension Array2d: Sequence {
    func makeIterator() -> TwoDimensionalIterator<T> {
        return TwoDimensionalIterator(self)
    }
}

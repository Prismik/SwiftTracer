//
//  array2d.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import Foundation

/// Allows linear iteration on every `Array2d` elements.
struct TwoDimensionalIterator<T: AdditiveArithmetic>: IteratorProtocol {
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

/// Two-dimensional array represented as a one dimensional array.
class Array2d<T: AdditiveArithmetic> {
    /// Typically the length.
    private(set) var xSize: Int
    /// Typically the height.
    private(set) var ySize: Int

    /// Total number of elements
    var size: Int { storage.count }

    /// Total value contained in storage
    private(set) var total: T = .zero

    private var storage: [T]

    private let lock = NSLock()

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
    
    init?(contentsOf filename: String) {
        
        self.xSize = 0
        self.ySize = 0
        self.storage = Array()
    }

    /// Gets the value at index (x, y).
    func get(_ x: Int, _ y: Int) -> T {
        return storage[index(x, y)]
    }
    
    /// Sets the value at index (x, y).
    func set(value: T, _ x: Int, _ y: Int) {
        let current = get(x, y)
        total += value - current
        storage[index(x, y)] = value
    }

    /// Adds `value` to the current value at index (x, y).
    func add(value: T, _ x: Int, _ y: Int) {
        lock.withLock {
            let current = storage[index(x, y)]
            total += value
            storage[index(x, y)] = current + value
        }
    }
    
    /// Adds `value` to the current value at value i.
    func add(value: T, i: Int) {
        lock.withLock {
            let current = storage[i]
            total += value
            storage[i] = current + value
        }
    }

    /// Substracts `value` to the current value at index (x, y)
    func substract(value: T, _ x: Int, _ y: Int) {
        let current = storage[index(x, y)]
        total -= value
        storage[index(x, y)] = current - value
    }
    
    /// For each values in `other`, add them into `self`.
    func merge(with other: Array2d<T>) {
        for (i, val) in other.enumerated() {
            add(value: val, i: i)
        }
    }

    /// Flips the value vertically, such that the element at (0, 0) becomes (0, n), where n is the `ySize`.
    /// > Tip: This is particularly useful for the image information that gets read with the coordinate system of:
    /// > - **X** (from: left, to: right)
    /// > - **Y** (from: up, to: bottom)
    /// > - **Z** (from: away from the camera, to: towards the camera)
    /// >
    /// > With this function, we can easily can bring it back to **Y** (from: bottom: to: up).
    func flipVertically() {
        let copy = Array2d(copy: self)
        for (i, item) in self.enumerated() {
            let (x, y) = index2d(i)
            copy.set(value: item, x, ySize - 1 -  y)
        }
        
        self.storage = copy.storage
    }

    internal func index(_ x: Int, _ y: Int) -> Int {
        return y * xSize + x
    }
    
    internal func index2d(_ i: Int) -> (Int, Int) {
        return (i % xSize, i / xSize)
    }
}

extension Array2d: Sequence {
    func makeIterator() -> TwoDimensionalIterator<T> {
        return TwoDimensionalIterator(self)
    }
}

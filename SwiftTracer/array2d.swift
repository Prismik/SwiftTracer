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
        
        return array[cx, cy]
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
        self.storage = Array(copy.storage)
    }
    
    init(xSize: Int, ySize: Int, storage: [T]) {
        self.xSize = xSize
        self.ySize = ySize
        self.storage = storage
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

    subscript(i: Int) -> T {
        get {
            storage[i]
        }
        set {
            lock.withLock {
                let current = storage[i]
                total += newValue - current
                storage[i] = newValue
            }
        }
    }
    
    subscript(x: Int, y: Int) -> T {
        get {
            storage[index(x, y)]
        }
        set {
            lock.withLock {
                let index = index(x, y)
                let current = storage[index]
                total += newValue - current
                storage[index] = newValue
            }
        }
    }
    
    /// Adds `value` to the current value at ith element in the storage.
    func add(value: T, i: Int) {
        lock.withLock {
            let current = storage[i]
            total += value
            storage[i] = current + value
        }
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
            copy[x, ySize - 1 -  y] = item
        }
        
        self.storage = copy.storage
    }

    /// Applies the transformator `t` on each of the values, mutating the storage in place.
    func transform(_ t: (T) -> T) {
        for (i, value) in storage.enumerated() {
            storage[i] = t(value)
        }
    }
    
    /// Applies the transformator `t` on each of the values, mutating the storage in place and returning the updated version of `self`.
    func transformed(_ t: (T) -> T) -> Array2d<T> {
        let copy = Array2d(copy: self)
        for (i, value) in storage.enumerated() {
            copy.storage[i] = t(value)
        }
        
        return copy
    }

    internal func index(_ x: Int, _ y: Int) -> Int {
        return y * xSize + x
    }
    
    internal func index2d(_ i: Int) -> (Int, Int) {
        return (i % xSize, i / xSize)
    }
}

extension Array2d {
    static func +(lhs: Array2d, rhs: Array2d) -> Array2d {
        guard lhs.size == rhs.size else {
            fatalError("Attempting to add \(lhs.size) sized Array2d to \(rhs.size) sized Array2d. Size values must match.")
        }

        return Array2d(xSize: lhs.xSize, ySize: lhs.ySize, storage: zip(lhs.storage, rhs.storage).map(+))
    }
    
    static func +=(lhs: inout Array2d, rhs: Array2d) {
        lhs = lhs + rhs
    }
}

extension Array2d: Sequence {
    func makeIterator() -> TwoDimensionalIterator<T> {
        return TwoDimensionalIterator(self)
    }
}

extension Array2d<Color> {
    func scale(by factor: Float) {
        for (i, item) in self.enumerated() {
            let (x, y) = index2d(i)
            self[x, y] = item * factor
        }
    }
}

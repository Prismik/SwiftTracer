//
//  PixelBuffer.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import Foundation
#if os(Linux)
typealias PixelBuffer = Array2d<Color>
#else
import Accelerate

/// Allows linear iteration on every `PixelBuffer` elements.
struct PixelBufferIterator: IteratorProtocol {
    var x: Int = 0
    var y: Int = 0
    
    private let buffer: PixelBuffer
    
    init(_ buffer: PixelBuffer) {
        self.buffer = buffer
    }

    mutating func next() -> Color? {
        guard y < buffer.height && x < buffer.width else { return nil }
        let (cx, cy) = (x, y)
        let next = (x + 1) % buffer.width
        if next == 0 {
            y += 1
        }
        
        x = next
        
        return buffer[cx, cy]
    }
}

class PixelBuffer {
    private(set) var width: Int
    private(set) var height: Int
    /// Total number of elements
    var size: Int { width * height }
    
    private var internalWidth: Int
    private var internalHeight: Int
    private var internalSize: Int { internalWidth * internalHeight }
    
    
    /// Total value contained in storage
    private(set) var total: Color = .zero
    
    private var storage: [Float]
    
    private let lock = NSLock()
    
    init() {
        self.width = 0
        self.height = 0
        self.internalWidth = 0
        self.internalHeight = 0
        self.storage = []
    }
    
    init(copy: PixelBuffer) {
        self.internalWidth = copy.internalWidth
        self.internalHeight = copy.internalHeight
        self.width = copy.width
        self.height = copy.height
        self.storage = Array(copy.storage)
        self.total = copy.total
    }
    
    init(width: Int, height: Int, storage: [Float]) {
        self.internalWidth = width * 3
        self.internalHeight = height
        self.width = width
        self.height = height
        self.storage = storage
    }
    
    init(width: Int, height: Int, value: Color) {
        self.internalWidth = width * 3
        self.internalHeight = height
        self.width = width
        self.height = height
        
        let size = internalWidth * internalHeight
        var converted: [Float] = []
        converted.reserveCapacity(size)
        for _ in 0 ..< size / 3 {
            converted.append(value.x)
            converted.append(value.y)
            converted.append(value.z)
            total += value
        }
        
        self.storage = converted
    }
    
    subscript(i: Int) -> Color {
        get {
            let index = i * 3
            return Color(storage[index], storage[index+1], storage[index+2])
        }
        set {
            lock.withLock {
                let index = i * 3
                let r = storage[index]
                let g = storage[index+1]
                let b = storage[index+2]

                storage[index] = newValue.x
                storage[index+1] = newValue.y
                storage[index+2] = newValue.z
                
                total += Color(storage[index], storage[index+1], storage[index+2]) - Color(r, g, b)
            }
        }
    }
    
    subscript(x: Int, y: Int) -> Color {
        get {
            let index = index(x, y)
            return Color(storage[index], storage[index+1], storage[index+2])
        }
        set {
            lock.withLock {
                let index = index(x, y)
                
                let r = storage[index]
                let g = storage[index+1]
                let b = storage[index+2]

                storage[index] = newValue.x
                storage[index+1] = newValue.y
                storage[index+2] = newValue.z
                
                total += Color(storage[index], storage[index+1], storage[index+2]) - Color(r, g, b)
            }
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
        let copy = PixelBuffer(copy: self)
        for i in stride(from: 0, to: internalSize, by: 3) {
            let item = self[i / 3]
            let (x, y) = index2d(i / 3)
            copy[x, height - 1 - y] = item
        }
        self.storage = copy.storage
    }
    
    /// Applies the transformator `t` on each of the values, mutating the storage in place.
    func transform(_ t: (Color) -> Color) {
        // TODO Update total
        for i in stride(from: 0, to: internalSize, by: 3) {
            let c = Color(storage[i], storage[i+1], storage[i+2])
            let val = t(c)
            storage[i] = val.x
            storage[i+1] = val.y
            storage[i+2] = val.z
        }
    }
    
    /// Applies the transformator `t` on each of the values, mutating the storage in place and returning the updated version of `self`.
    func transformed(_ t: (Color) -> Color) -> PixelBuffer {
        let copy = PixelBuffer(copy: self)
        for i in stride(from: 0, to: internalSize, by: 3) {
            let c = Color(copy.storage[i], copy.storage[i+1], copy.storage[i+2])
            let val = t(c)
            copy.storage[i] = val.x
            copy.storage[i+1] = val.y
            copy.storage[i+2] = val.z
        }
        return copy
    }

    // TODO Update total
    func scale(by factor: Float) {
        lock.withLock {
            self.storage = vDSP.multiply(factor, storage)
            self.total *= factor
        }
    }
    
    // TODO Update total
    func merge(with buffer: PixelBuffer) {
        lock.withLock {
            self.storage = vDSP.add(buffer.storage, self.storage)
            self.total += buffer.total
        }
    }
    
    internal func index(_ x: Int, _ y: Int) -> Int {
        return y * internalWidth + x * 3
    }
    
    internal func index2d(_ i: Int) -> (Int, Int) {
        return (i % width, i / width)
    }

    static var empty: PixelBuffer {
        return PixelBuffer()
    }
}

extension PixelBuffer {
    static func +(lhs: PixelBuffer, rhs: PixelBuffer) -> PixelBuffer {
        guard lhs.size == rhs.size else {
            fatalError("Attempting to add \(lhs.size) sized Array2d to \(rhs.size) sized Array2d. Size values must match.")
        }

        let combined = vDSP.add(lhs.storage, rhs.storage)
        return PixelBuffer(width: lhs.width, height: lhs.height, storage: combined)
    }
    
    static func +=(lhs: inout PixelBuffer, rhs: PixelBuffer) {
        lhs = lhs + rhs
    }
}

extension PixelBuffer: Sequence {
    func makeIterator() -> PixelBufferIterator {
        return PixelBufferIterator(self)
    }
}
#endif

/// Allows linear iteration on every `Array2d` elements.
struct TwoDimensionalIterator<T: AdditiveArithmetic>: IteratorProtocol {
    var x: Int = 0
    var y: Int = 0
    
    private let array: Array2d<T>
    
    init(_ array: Array2d<T>) {
        self.array = array
    }

    mutating func next() -> T? {
        guard y < array.height && x < array.width else { return nil }
        let (cx, cy) = (x, y)
        let next = (x + 1) % array.width
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
    private(set) var width: Int
    /// Typically the height.
    private(set) var height: Int

    /// Total number of elements
    var size: Int { storage.count }

    /// Total value contained in storage
    private(set) var total: T = .zero

    private var storage: Array<T>

    private let lock = NSLock()

    init() {
        self.width = 0
        self.height = 0
        self.storage = []
    }
    
    init(copy: Array2d<T>) {
        self.width = copy.width
        self.height = copy.height
        self.storage = Array(copy.storage)
    }
    
    init(width: Int, height: Int, storage: [T]) {
        self.width = width
        self.height = height
        self.storage = storage
    }

    init(width: Int, height: Int, value: T) {
        self.width = width
        self.height = height
        self.storage = Array(repeating: value, count: width * height)
    }
    
    init?(contentsOf filename: String) {
        self.width = 0
        self.height = 0
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
            copy[x, height - 1 -  y] = item
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
        return y * width + x
    }
    
    internal func index2d(_ i: Int) -> (Int, Int) {
        return (i % width, i / width)
    }
}

extension Array2d {
    static func +(lhs: Array2d, rhs: Array2d) -> Array2d {
        guard lhs.size == rhs.size else {
            fatalError("Attempting to add \(lhs.size) sized Array2d to \(rhs.size) sized Array2d. Size values must match.")
        }

        return Array2d(width: lhs.width, height: lhs.height, storage: zip(lhs.storage, rhs.storage).map(+))
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

    static var empty: Array2d<Color> {
        return Array2d<Color>()
    }
}

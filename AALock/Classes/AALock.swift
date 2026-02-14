//
//  AALock.swift
//  AALock
//
//  Created by Aaron Feng on 2025/7/27.
//

import Foundation

public protocol AARWLockProtocol: NSLocking {
    func readLock()
    func writeLock()
}

public extension NSLocking {
    @discardableResult
    func lock<T>(_ block: () throws -> T) rethrows -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return try block()
    }
}

public extension AARWLockProtocol {
    @discardableResult
    func readLock<T>(_ block: () throws -> T) rethrows -> T {
        self.readLock()
        defer {
            self.unlock()
        }
        return try block()
    }
    
    @discardableResult
    func writeLock<T>(_ block: () throws -> T) rethrows -> T {
        self.writeLock()
        defer {
            self.unlock()
        }
        return try block()
    }
}

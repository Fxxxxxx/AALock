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
    func lock<T>(_ block: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return block()
    }
}

public extension AARWLockProtocol {
    func readLock<T>(_ block: () -> T) -> T {
        self.readLock()
        defer {
            self.unlock()
        }
        return block()
    }
    
    func writeLock<T>(_ block: () -> T) -> T {
        self.writeLock()
        defer {
            self.unlock()
        }
        return block()
    }
}

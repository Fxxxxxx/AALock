//
//  AALockedValue.swift
//  AALock
//
//  Created by Aaron on 2026/2/14.
//

import Foundation

// MARK: - 核心封装类：锁 + 数据 一体化
public final class AALockedValue<Value>: @unchecked Sendable {
    /// 被保护的原始数据（私有化，仅通过闭包访问）
    private var _value: Value
    /// 用于保护数据的锁（基于 NSLocking 协议，兼容 AAUnfairLock/NSLock 等）
    private let lock: NSLocking
    
    /// 自定义锁初始化（兼容任意遵循 NSLocking 的锁）
    /// - Parameters:
    ///   - value: 初始数据
    ///   - lock: 自定义锁（如 AAUnfairLock/NSLock 等）
    public init(value: Value, lock: NSLocking = AAUnfairLock()) {
        self._value = value
        self.lock = lock
    }
    
    // MARK: iOS 18 风格核心 API（自动加解锁）
    /// 加锁访问并修改数据（互斥锁语义，自动加解锁）
    /// - Parameter block: 闭包内可读写数据，闭包返回值会更新原始数据
    /// - Returns: 闭包执行结果
    @discardableResult
    public func withLock<T>(_ block: (inout Value) -> T) -> T {
        lock.lock {
            block(&_value)
        }
    }
    
    // MARK: 便捷取值 API
    /// 加读锁快速获取数据（只读，自动加解锁）
    public var value: Value {
        withLock { $0 }
    }
    
}

// MARK: - 核心封装类：锁 + 数据 一体化
public final class AARWLockedValue<Value>: @unchecked Sendable {
    /// 被保护的原始数据（私有化，仅通过闭包访问）
    private var _value: Value
    /// 用于保护数据的锁（兼容读写锁/普通锁）
    private let lock: any AARWLockProtocol
    
    /// 初始化方法
    /// - Parameters:
    ///   - value: 初始数据
    ///   - lock: 用于保护数据的锁（需遵循 AARWLockProtocol）
    public init(value: Value, lock: any AARWLockProtocol = AARWLock()) {
        self._value = value
        self.lock = lock
    }
    
    // MARK: - 普通锁 API（兼容 NSLocking）
    /// 加锁访问并修改数据（写操作，无论读写锁/普通锁都走写锁逻辑）
    /// - Parameter block: 闭包内可读写数据，闭包返回值会更新原始数据
    /// - Returns: 闭包执行结果
    @discardableResult
    public func withLock<T>(_ block: (inout Value) -> T) -> T {
        lock.lock {
            block(&_value)
        }
    }
    
    // MARK: - 读写锁专属 API
    /// 加读锁访问数据（仅读，不可修改）
    /// - Parameter block: 闭包内只读数据
    /// - Returns: 闭包执行结果
    @discardableResult
    public func withReadLock<T>(_ block: (Value) -> T) -> T {
        lock.readLock {
            block(_value)
        }
    }
    
    /// 加写锁访问并修改数据（读写锁专属写操作）
    /// - Parameter block: 闭包内可读写数据，闭包返回值会更新原始数据
    /// - Returns: 闭包执行结果
    @discardableResult
    public func withWriteLock<T>(_ block: (inout Value) -> T) -> T {
        lock.writeLock {
            block(&_value)
        }
    }
    
    // MARK: - 便捷取值 API
    /// 加读锁快速获取数据（只读）
    public var value: Value {
        withReadLock { $0 }
    }
}

//
//  AARWLock.swift
//  AALock
//
//  Created by Aaron Feng on 2025/7/27.
//

import Foundation

@objcMembers
public final class AARWLock: NSObject, AARWLockProtocol {
    
    private var rwLock: pthread_rwlock_t = .init()
    public override init() {
        pthread_rwlock_init(&rwLock, nil)
    }
    
    deinit {
        pthread_rwlock_destroy(&rwLock)
    }
    
    public func writeLock() {
        pthread_rwlock_wrlock(&rwLock)
    }
    
    public func readLock() {
        pthread_rwlock_rdlock(&rwLock)
    }
    
    public func lock() {
        self.writeLock()
    }
    
    public func unlock() {
        pthread_rwlock_unlock(&rwLock)
    }

}

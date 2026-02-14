//
//  AAUnfairLock.swift
//  AALock
//
//  Created by Aaron Feng on 2025/7/27.
//

import Foundation

@objcMembers
public final class AAUnfairLock: NSObject, NSLocking, @unchecked Sendable {
    
    private var ufLock: os_unfair_lock = .init()
    
    public func lock() {
        os_unfair_lock_lock(&ufLock)
    }
    
    public func unlock() {
        os_unfair_lock_unlock(&ufLock)
    }
    
}

//
//  Example.m
//  AALock_Example
//
//  Created by Aaron Feng on 2025/7/27.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

#import "Example.h"
#import <mutex>
#import <AALock/AALock-Swift.h>
#import <AALock/AALockDefine.h>

static void cppExample(void) {
    
    std::mutex mtx;
    /// 作用域结束，自动解锁
    std::lock_guard<std::mutex> lk(mtx);
    
}

@implementation Example

- (void)example {
    
    /// 创建读写锁
    AARWLock *rdLock = [AARWLock new];
    {
        @AAScopedWriteLock(rdLock);
        /// 读操作，作用域结束自动解锁
    }
    {
        @AAScopedWriteLock(rdLock);
        /// 写操作，作用域结束自动解锁
    }
    
    /// 创建互斥锁
    AAUnfairLock *lock = [AAUnfairLock new];
    {
        @AAScopedLock(lock);
        /// 已加锁，作用域结束自动解锁
    }
}

@end

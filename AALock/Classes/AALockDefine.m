//
//  AALockDefine.m
//  AALock
//
//  Created by Aaron Feng on 2025/7/27.
//

#import "AALockDefine.h"
#import <AALock/AALock-Swift.h>

void aa_executeCleanupBlock (__strong dispatch_block_t *block) {
    (*block)();
}

//
//  AALockDefine.h
//  AALock
//
//  Created by Aaron Feng on 2025/7/27.
//

#import <Foundation/Foundation.h>

#define aa_metamacro_concat_(A, B) A ## B
#define aa_metamacro_concat(A, B) aa_metamacro_concat_(A, B)

#if DEBUG
#define aa_keywordify autoreleasepool {}
#else
#define aa_keywordify try {} @catch (...) {}
#endif

#define aaDefer \
aa_keywordify \
__strong aa_cleanupBlock_t aa_metamacro_concat(aa_exitBlock_, __LINE__) __attribute__((cleanup(aa_executeCleanupBlock), unused)) = ^

typedef void (^aa_cleanupBlock_t)(void);

#if defined(__cplusplus)
extern "C" {
#endif
    void aa_executeCleanupBlock (__strong aa_cleanupBlock_t *block);
#if defined(__cplusplus)
}
#endif

#define AAScopedLock(lock) \
aa_keywordify \
[lock lock]; \
@aaDefer { \
[lock unlock]; \
}

#define AAScopedWriteLock(lock) \
aa_keywordify \
[lock writeLock]; \
@aaDefer { \
[lock unlock]; \
}

#define AAScopedReadLock(lock) \
aa_keywordify \
[lock readLock]; \
@aaDefer { \
[lock unlock]; \
}

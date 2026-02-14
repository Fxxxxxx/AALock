# 适配Swift 6 Sendable：用AALock优雅解决线程安全与不可变引用难题

Swift 6 带来的 `Sendable` 协议是并发安全领域的重要升级，它强制要求跨线程传递的类型具备明确的线程安全语义。但在实际开发中，我们常会陷入一个两难境地：**既要满足 Sendable 对不可变引用（let）的要求，又要保证非线程安全对象的并发访问安全**。本文将介绍我封装的 `AALock` 工具库，它既能完美适配 Swift 6 Sendable 检查，又能以极简的方式实现线程安全，让你的代码在 Swift 6 并发模型下既合规又优雅。

> 本组件的设计思路参考了 iOS 18 原生 mutex 锁的设计理念，通过封装适配层实现了低版本 iOS 系统的兼容使用，既保留了原生高性能特性，又解决了不同系统版本下线程安全锁的适配问题。

## 一、Swift 6 Sendable 的核心痛点
### 1. Sendable 对“不可变”的强约束
`Sendable` 协议的核心要求之一是：**符合 Sendable 的类型，其属性应优先使用 let（不可变）修饰**。如果类型中存在 `var` 修饰的引用类型属性（比如 `var dict: [String: Any]`），编译器会直接判定该类型不满足 Sendable，导致无法安全地跨 actor/线程传递。

但现实场景中，我们不可能所有数据都做成不可变——业务逻辑必然需要修改数组、字典、自定义对象等，直接用 `let` 修饰非线程安全对象，又会带来并发访问的线程安全问题。

### 2. 传统解决方案的弊端
为了兼顾 Sendable 和线程安全，传统做法通常有两种，但都有明显缺陷：
- **方案1**：用 `var` 修饰属性 + 手动加锁。直接违反 Sendable 对不可变引用的要求，编译器报错，无法通过检查；
- **方案2**：封装成不可变容器 + 拷贝修改。每次修改都生成新对象，性能开销大，且代码冗余，违背“最小修改成本”原则。

## 二、AALock 的核心设计思路
`AALock` 的核心目标是：**让非线程安全对象通过 `let` 修饰仍能安全修改，同时满足 Sendable 检查**。其设计围绕两个核心封装展开：

### 1. 核心思想：“不可变容器 + 内部可变 + 自动加锁”
- 用 `let` 修饰 `AALock` 包装后的对象（满足 Sendable 对不可变引用的要求）；
- 容器内部维护需要修改的非线程安全对象，通过锁（不公平锁/读写锁）保证修改的线程安全；
- 对外暴露极简的闭包式 API，自动处理加锁/解锁，避免手动操作的漏解锁风险。

### 2. 核心组件
| 组件 | 适用场景 | 核心优势 |
|------|----------|----------|
| `AAUnfairLock` | 通用互斥场景 | 基于系统 `os_unfair_lock`，性能优于 `NSLock`，无递归重入 |
| `AARWLock` | 读多写少场景 | 读写分离，读操作并发执行，写操作互斥，性能远超普通互斥锁 |
| `AALockedValue` | 通用线程安全封装 | 基于 `AAUnfairLock`，包装任意类型，闭包式操作，自动加解锁 |
| `AARWLockedValue` | 读多写少的高性能场景 | 基于 `AARWLock`，读写锁分离，最大化读操作并发性能 |

## 三、AALock 如何适配 Sendable？
### 1. 关键特性：let 修饰仍可安全修改
通过 `AALockedValue`/`AARWLockedValue` 包装后，我们可以用 `let` 修饰属性（满足 Sendable），同时通过闭包修改内部数据（线程安全）：

```swift
// 符合 Sendable 的自定义类型
struct SafeData: Sendable {
    // let 修饰，满足 Sendable 不可变要求
    let lockedDict = AALockedValue(value: [String: String]())
    let rwLockedArray = AARWLockedValue(value: [Int]())
}

// 跨线程传递（满足 Sendable 检查）
let safeData = SafeData()
DispatchQueue.global().async {
    // 写操作：自动加锁，线程安全
    safeData.lockedDict.withLock { dict in
        dict["key"] = "value"
    }
    
    // 读操作：自动加锁，线程安全
    let value = safeData.lockedDict.withLock { dict in
        dict["key"]
    }
    print("读取值：\(value ?? "nil")")
}
```

### 2. 底层适配 Sendable 协议
`AALock` 核心组件均遵循 `Sendable` 协议，确保包装后的对象可安全跨线程传递：

```swift
// AALockedValue 核心定义（简化版）
public final class AALockedValue<Value>: Sendable {
    private let lock: AAUnfairLock
    private var _value: Value
    
    public init(value: Value, lock: AAUnfairLock = AAUnfairLock()) {
        self._value = value
        self.lock = lock
    }
    
    // 闭包式操作，自动加解锁
    public func withLock<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        try lock.lock {
            try body(&_value)
        }
    }
    
    // 便捷取值（自动加锁）
    public var value: Value {
        withLock { $0 }
    }
}
```

关键设计点：
- 用 `final class` 避免继承带来的线程安全风险；
- 内部 `_value` 用 `var` 修饰（仅内部可变），对外暴露 `let` 容器；
- 所有操作通过闭包封装，确保锁的范围精准，避免手动解锁遗漏；
- 遵循 `Sendable` 协议，可直接跨 actor/线程传递。

## 四、AALock 核心用法示例
### 1. 基础用法：普通互斥锁（AAUnfairLock）
```swift
let lock = AAUnfairLock()
var dict = [String: String]()

// 闭包式加解锁（推荐）
lock.lock {
    dict["name"] = "AALock"
    dict["version"] = "1.0.0"
}

// 手动加解锁（兼容场景）
lock.lock()
let name = dict["name"]
lock.unlock()
```

### 2. 高性能场景：读写锁（AARWLock）
读多写少场景下，读写锁性能远超普通互斥锁：
```swift
let rwLock = AARWLock()
let rwLockedArray = AARWLockedValue(value: [Int]())

// 写锁：互斥操作，修改数据
rwLockedArray.withWriteLock { array in
    array.append(contentsOf: [1,2,3,4,5])
}

// 读锁：并发读取，性能最优
DispatchQueue.concurrentPerform(iterations: 10) { _ in
    let count = rwLockedArray.withReadLock { array in
        array.count
    }
    print("数组长度：\(count)")
}
```

### 3. 完整 Sendable 适配示例
```swift
// 自定义 Sendable 类型
class BusinessManager: Sendable {
    // let 修饰，满足 Sendable
    private let userCache = AALockedValue(value: [String: User]())
    private let statisticData = AARWLockedValue(value: [String: Int]())
    
    // 新增用户（写操作）
    func addUser(_ user: User, id: String) {
        userCache.withLock { cache in
            cache[id] = user
        }
    }
    
    // 获取用户（读操作）
    func getUser(id: String) -> User? {
        userCache.withLock { cache in
            cache[id]
        }
    }
    
    // 统计数据（读多写少）
    func incrementStatistic(key: String) {
        statisticData.withWriteLock { data in
            data[key, default: 0] += 1
        }
    }
    
    func getStatistic(key: String) -> Int {
        statisticData.withReadLock { data in
            data[key] ?? 0
        }
    }
}

// 跨 Actor 传递（Swift 6 并发模型）
actor UserActor {
    func handleManager(_ manager: BusinessManager) {
        let count = manager.getStatistic(key: "login")
        print("登录次数：\(count)")
    }
}

// 调用示例
let manager = BusinessManager()
let actor = UserActor()
Task {
    await actor.handleManager(manager) // 无 Sendable 警告
}
```

## 五、AALock 的核心优势
### 1. 完美适配 Swift 6 Sendable
- 用 `let` 修饰包装后的对象，满足 Sendable 对不可变引用的要求；
- 所有核心组件遵循 `Sendable`，无编译器警告，直接通过 Swift 6 严格检查。

### 2. 极致的性能
- 基于 `os_unfair_lock` 实现 `AAUnfairLock`，性能远超 `NSLock`/`pthread_mutex_t`；
- 读写锁 `AARWLock` 针对读多写少场景做优化，读操作并发执行，性能提升数倍。

### 3. 极简的 API 设计
- 闭包式加解锁，避免手动 `lock()`/`unlock()` 导致的漏解锁、死锁问题；
- 支持任意类型的包装（基础类型、集合、自定义对象），无侵入式修改。

### 4. 零学习成本
- API 语义清晰（`withLock`/`withReadLock`/`withWriteLock`），一看就会；
- 无需修改原有业务逻辑，仅需包装非线程安全对象即可。

## 六、总结与推广
Swift 6 的 `Sendable` 协议是未来并发编程的标配，而线程安全是跨线程开发的基础要求。`AALock` 既解决了 Sendable 对不可变引用的强约束，又通过极简的 API 实现了线程安全，让开发者无需在“合规”和“易用”之间妥协。

### 适用场景
- Swift 6 项目中需要满足 Sendable 检查的跨线程类型；
- 读多写少的高性能并发场景（如缓存、统计数据）；
- 任意需要线程安全的非线程安全对象（数组、字典、自定义 struct/class）。

### 接入建议
1. 将 `AALock` 集成到项目中（支持 CocoaPods/Carthage/Swift Package Manager）；
2. 将原有 `var` 修饰的非线程安全属性，替换为 `let` 修饰的 `AALockedValue`/`AARWLockedValue`；
3. 通过 `withLock`/`withReadLock`/`withWriteLock` 操作内部数据，无需手动加锁。

`AALock` 让 Swift 6 并发编程更简单、更安全、更合规，如果你也在适配 Swift 6 Sendable，或者需要优雅解决线程安全问题，不妨试试这个封装——它会成为你 Swift 6 并发开发的“瑞士军刀”。

> 项目地址：[GitHub - AALock](https://github.com/Fxxxxxx/AALock)（替换为实际地址）  
> 欢迎 Star、Fork、PR，一起完善 Swift 6 并发安全生态！
//
//  ViewController.swift
//  AALock
//
//  Created by AaronFeng on 07/27/2025.
//  Copyright (c) 2025 AaronFeng. All rights reserved.
//

import UIKit
import AALock

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // 执行所有示例
        basicLockExample()
        lockedValueBasicExample()
        rwLockedValueReadWriteExample()
        multiThreadPerformanceExample()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: 1. 基础锁（AAUnfairLock/AARWLock）原生使用示例
    func basicLockExample() {
        print("\n===== 基础锁使用示例 =====")
        // 普通不公平锁（互斥锁）
        var dict = [String: String]()
        let unfairLock = AAUnfairLock()
        
        // 闭包式加解锁（推荐）
        unfairLock.lock {
            dict["name"] = "Aaron"
            print("基础锁 - 设置值: \(dict["name"] ?? "")")
        }
        
        // 手动加解锁（不推荐，仅演示）
        unfairLock.lock()
        if let name = dict["name"] {
            print("基础锁 - 手动解锁读取: \(name)")
        }
        unfairLock.unlock()
        
        // 读写锁原生使用
        let rwLock = AARWLock()
        // 写锁（互斥）
        rwLock.writeLock {
            dict["age"] = "28"
            print("读写锁 - 写锁设置age: \(dict["age"] ?? "")")
        }
        // 读锁（支持并发）
        let age = rwLock.readLock {
            return dict["age"] ?? "未知"
        }
        print("读写锁 - 读锁读取age: \(age)")
    }
    
    // MARK: 2. AALockedValue（普通互斥锁封装）使用示例
    func lockedValueBasicExample() {
        print("\n===== AALockedValue 使用示例 =====")
        // 初始化：保护Int类型数据（默认用AAUnfairLock）
        let lockedInt = AALockedValue(value: 0)
        // 初始化：保护自定义类型（比如字典）
        let lockedDict = AALockedValue(value: [String: Any](), lock: NSLock())
        
        // 1. 基础读写操作
        lockedInt.withLock { value in
            value += 10
            print("AALockedValue - 修改Int值: \(value)")
        }
        
        // 2. 便捷取值（自动加读锁）
        print("AALockedValue - 便捷取值: \(lockedInt.value)")
        
        // 3. 复杂数据操作（字典）
        lockedDict.withLock { dict in
            dict["count"] = 5
            dict["items"] = ["Apple", "Banana", "Orange"]
            print("AALockedValue - 字典操作后count: \(dict["count"] ?? 0)")
        }
        
        // 4. 多线程并发修改（验证线程安全）
        let group = DispatchGroup()
        for i in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                lockedInt.withLock { value in
                    value += 1
                    // 仅最后一次打印，避免日志刷屏
                    if i == 9 {
                        print("AALockedValue - 多线程累加后: \(value)")
                    }
                }
                group.leave()
            }
        }
        group.wait()
    }
    
    // MARK: 3. AARWLockedValue（读写锁封装）使用示例
    func rwLockedValueReadWriteExample() {
        print("\n===== AARWLockedValue 使用示例 =====")
        // 初始化：保护数组（读多写少场景）
        let rwLockedArray = AARWLockedValue(value: [Int]())
        
        // 1. 写锁：添加元素（互斥）
        rwLockedArray.withWriteLock { array in
            array.append(contentsOf: [1, 2, 3, 4, 5])
            print("AARWLockedValue - 写锁添加元素: \(array)")
        }
        
        // 2. 读锁：并发读取（性能最优）
        let readGroup = DispatchGroup()
        for i in 0..<5 {
            readGroup.enter()
            DispatchQueue.global().async {
                let count = rwLockedArray.withReadLock { array in
                    return array.count
                }
                print("AARWLockedValue - 读锁\(i)读取数组长度: \(count)")
                readGroup.leave()
            }
        }
        readGroup.wait()
        
        // 3. 便捷取值（自动加读锁）
        print("AARWLockedValue - 便捷取值: \(rwLockedArray.value)")
    }
    
    // MARK: 4. 读写锁 vs 普通锁 性能对比示例（读多写少场景）
    func multiThreadPerformanceExample() {
        print("\n===== 性能对比示例（读多写少） =====")
        // 准备数据
        let normalLockValue = AALockedValue(value: [Int](1...1000))
        let rwLockValue = AARWLockedValue(value: [Int](1...1000))
        
        // 记录耗时
        func measureTime(tag: String, block: () -> Void) {
            let start = CFAbsoluteTimeGetCurrent()
            block()
            let end = CFAbsoluteTimeGetCurrent()
            print("\(tag) 耗时: \(String(format: "%.4f", end - start))秒")
        }
        
        // 场景：1000次读 + 10次写
        let readCount = 1000
        let writeCount = 10
        
        // 普通锁耗时
        measureTime(tag: "普通锁（AALockedValue）") {
            let group = DispatchGroup()
            // 1000次读
            for _ in 0..<readCount {
                group.enter()
                DispatchQueue.global().async {
                    _ = normalLockValue.value
                    group.leave()
                }
            }
            // 10次写
            for i in 0..<writeCount {
                group.enter()
                DispatchQueue.global().async {
                    normalLockValue.withLock { array in
                        array.append(i)
                    }
                    group.leave()
                }
            }
            group.wait()
        }
        
        // 读写锁耗时
        measureTime(tag: "读写锁（AARWLockedValue）") {
            let group = DispatchGroup()
            // 1000次读（并发）
            for _ in 0..<readCount {
                group.enter()
                DispatchQueue.global().async {
                    _ = rwLockValue.value
                    group.leave()
                }
            }
            // 10次写（互斥）
            for i in 0..<writeCount {
                group.enter()
                DispatchQueue.global().async {
                    rwLockValue.withWriteLock { array in
                        array.append(i)
                    }
                    group.leave()
                }
            }
            group.wait()
        }
    }
    
}

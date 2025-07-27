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
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func example() {
        
        var dict = [String: String]()
        
        let lock = AAUnfairLock()
        lock.lock {
            /// 锁范围内
            dict["key"] = "value"
        }
        
        let rdLock = AARWLock()
        rdLock.writeLock {
            /// 写锁
            dict["key"] = "value"
        }
        _ = rdLock.readLock {
            /// 读锁
            return dict["key"]
        }
    }
    
}


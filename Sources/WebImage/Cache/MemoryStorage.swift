//
//  Created by vvgvjks on 2024/6/25.
//
//  Copyright © 2024 vvgvjks <vvgvjks@gmail.com>.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice
//  (including the next paragraph) shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
//  ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
//  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import os

@available(iOS 16.0, *)
class MemoryStorage: @unchecked Sendable {
    private var keys = Set<String>()
    private let lock = OSAllocatedUnfairLock()
    private let storage = NSCache<NSString, NSData>()
    
    init(countLimit: Int, totalCostLimit: Int) {
        storage.countLimit = countLimit
        storage.totalCostLimit = totalCostLimit
    }

    func value(forKey key: String) -> Data? {
        return storage.object(forKey: key as NSString) as Data?
    }
    
    func isCached(forKey key: String) -> Bool {
        return lock.withLock { keys.contains(key) }
    }
    
    func remove(forKey key: String) {
        let _ = lock.withLock { keys.remove(key) }
        storage.removeObject(forKey: key as NSString)
    }
    
    func removeAll() {
        lock.withLock { keys.removeAll() }
        storage.removeAllObjects()
    }
    
    /// 这里并不去检查 value 是否为空
    func store(value: Data, forKey key: String) {
        let _ = lock.withLock { keys.insert(key) }
        storage.setObject(value as NSData, forKey: key as NSString, cost: value.count)
    }
}

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

/// 内部错误在 debug 环境会输出日志.
/// 内部错误不会影响整体功能, 只会导致磁盘缓存的失效.
@available(iOS 16.0, *)
public final class CacheManager: Sendable {
    private let diskStorage: DiskStorage
    private let memoryStorage: MemoryStorage

    public enum CacheType {
        case disk
        case memory
    }

    /// todo 让 disk 也支持这两个参数
    public init(memoryCountLimit: Int, memoryTotalCostLimit: Int, directory: URL) {
        self.diskStorage = DiskStorage(directoryURL: directory)
        self.memoryStorage = MemoryStorage(countLimit: memoryCountLimit, totalCostLimit: memoryTotalCostLimit)
    }

    /// 只有磁盘缓存会抛出错误
    /// 如果磁盘缓存失效, 会被忽略
    public func value(forKey key: CacheKey) -> (Data, CacheType)? {
        let cacheKey = key.cacheKey()
        if let data = memoryStorage.value(forKey: cacheKey) {
            return (data, .memory)
        }
        /// 磁盘缓存失效, 就不用它
        if let data = try? diskStorage.value(forKey: cacheKey) {
            return (data, .disk)
        }
        return nil
    }

    /// 是否存在缓存
    public func isCached(forKey key: CacheKey) -> Bool {
        let cacheKey = key.cacheKey()
        if memoryStorage.isCached(forKey: cacheKey) {
            return true
        }
        if diskStorage.isCached(forKey: cacheKey) {
            return true
        }
        return false
    }

    /// 只有磁盘缓存会抛出错误
    public func removeAll() throws {
        memoryStorage.removeAll()
        try diskStorage.removeAll()
    }

    /// 只有磁盘缓存会抛出错误
    public func remove(forKey key: CacheKey) throws {
        let cacheKey = key.cacheKey()
        memoryStorage.remove(forKey: cacheKey)
        try diskStorage.remove(forKey: cacheKey)
    }

    /// 只有磁盘缓存会抛出错误, 需要外部考虑是否忽略
    public func store(value: Data, forKey key: CacheKey) throws {
        let cacheKey = key.cacheKey()
        memoryStorage.store(value: value, forKey: cacheKey)
        try diskStorage.store(value: value, forKey: cacheKey)
    }

    /// 仅存储在内存中
    public func storeInMemory(value: Data, forKey key: CacheKey) {
        memoryStorage.store(value: value, forKey: key.cacheKey())
    }

    /// 仅从内存中获取
    public func valueInMemory(forKey key: CacheKey) -> Data? {
        return memoryStorage.value(forKey: key.cacheKey())
    }
}

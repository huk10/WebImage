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
import OSLog

@available(iOS 14.0, *)
class DiskStorage: @unchecked Sendable{
    /// 存储根目录
    public let directoryURL: URL
    /// 目录是否已创建
    private var isCreatedDirectory = false
    private let fileManager = FileManager.default
    private var logger = Logger(subsystem: "com.vvgvjks.CacheManager", category: "cacheManager")

    /// 添加一层缓存, 检查缓存是否已存在
    var maybeCached: Set<String>?
    let maybeCachedCheckingQueue = DispatchQueue(label: "com.vvgvjks.maybeCachedCheckingQueue")

    /// 先不支持 limit cost 等限制, 删除文件比较麻烦.
    init(directoryURL: URL, isCacheSynchronized: Bool = false) {
        self.directoryURL = directoryURL
        prepareDirectory()
        setupCacheChecking()
    }
    
    func store(value: Data, forKey key: String, writeOptions: Data.WritingOptions = [], isCacheSynchronized: Bool = false) throws {
        if isCreatedDirectory == false {
            throw CacheError.cacheDirectoryDoesNotExist(directoryURL)
        }
        let fileURL = cacheFileURL(forKey: key)
        
        if isCacheSynchronized {
            do {
                /// 不用检查缓存是否存在, 如果缓存文件存在就覆盖
                return try value.write(to: fileURL, options: writeOptions)
            } catch {
                throw CacheError.writeToDiskFileData(fileURL, error)
            }
        }
        DispatchQueue.global(qos: .background).async {
            do {
                /// 不用检查缓存是否存在, 如果缓存文件存在就覆盖
                try value.write(to: fileURL, options: writeOptions)
            } catch {
                self.logger.warning("write cache file error: \(error, privacy: .public)")
            }
        }
    }
    
    func value(forKey key: String) throws -> Data? {
        if isCreatedDirectory == false {
            return nil
        }
        let fileURL = cacheFileURL(forKey: key)
        if isCached(forKey: key) == false {
            return nil
        }
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw CacheError.readDiskFileData(fileURL, error)
        }
    }
    
    func isCached(forKey key: String) -> Bool {
        /// 如果内存中标记这个 key 是存在的, 那它就存在
        if maybeCachedCheckingQueue.sync(execute: { self.maybeCached?.contains(key) ?? false }) {
            return true
        }
        return fileExists(cacheKey: key)
    }
    
    func remove(forKey key: String) throws {
        guard fileExists(cacheKey: key) else {
            return
        }
        try fileManager.removeItem(at: cacheFileURL(forKey: key))
    }
    
    func removeAll() throws {
        try fileManager.removeItem(at: directoryURL)
        prepareDirectory()
    }
    
    /// 创建存储根目录
    private func prepareDirectory() {
        if fileManager.fileExists(atPath: directoryURL.path) {
            isCreatedDirectory = true
            return
        }
        do {
            try fileManager.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)
            isCreatedDirectory = true
        } catch {
            isCreatedDirectory = false
            logger.warning("create caches directory error: \(error, privacy: .public)")
        }
    }
    
    /// 异步把 key 都加载到内存中.
    /// 再此期间都将直接去文件系统检查
    private func setupCacheChecking() {
        maybeCachedCheckingQueue.async {
            do {
                var cached: Set<String> = Set()
                try self.fileManager.contentsOfDirectory(atPath: self.directoryURL.path).forEach { key in
                    cached.insert(key)
                }
                self.maybeCached = cached
            } catch {
                self.maybeCached = nil
            }
        }
    }
    
    private func cacheFileURL(forKey key: String) -> URL {
        if #available(iOS 16.0, *) {
            let u = directoryURL
            return u.appending(path: key)
        } else {
            return directoryURL.appendingPathComponent(key, isDirectory: false)
        }
    }
    
    private func fileExists(cacheKey: String) -> Bool {
        if #available(iOS 16.0, *) {
            return fileManager.fileExists(atPath: directoryURL.appending(path: cacheKey).path())
        } else {
            return fileManager.fileExists(atPath: directoryURL.appendingPathComponent(cacheKey, isDirectory: false).path)
        }
    }
}

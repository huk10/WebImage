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

/// 带缓存的图片请求器
@available(iOS 16.0, *)
public class ImageLoader: @unchecked Sendable {
    public typealias onProgress = @Sendable (Int64, Int64) -> Void
    public typealias onCompletionHandler = @Sendable (DataResponse?, WebImageError?) -> Void

    private let network: Network
    private let cacheManager: CacheManager
    private let queue = DispatchQueue(label: "com.moss.WebImage.ImageLoader", attributes: .concurrent)

    public static let shard = ImageLoader()

    convenience init() {
        self.init(
            configuration: .ephemeral,
            concurrentCount: 5,
            memoryCountLimit: .max,
            memoryTotalCostLimit: 500 * 1024 * 1024,
            diskCacheStorageDirectory: .cachesDirectory.appending(path: "@image-caches")
        )
    }

    public init(
        configuration: URLSessionConfiguration,
        concurrentCount: Int = 5,
        memoryCountLimit: Int,
        memoryTotalCostLimit: Int,
        diskCacheStorageDirectory: URL
    ) {
        self.network = Network(configuration: configuration, concurrencyCount: concurrentCount)
        self.cacheManager = CacheManager(
            memoryCountLimit: memoryCountLimit,
            memoryTotalCostLimit: memoryTotalCostLimit,
            directory: diskCacheStorageDirectory
        )
    }
}

@available(iOS 16.0, *)
extension ImageLoader {
    /// 从缓存中加载数据
    private func loadDataFromCache(source: ImageSource, options: LoaderOptions) -> DataResponse? {
        /// 只使用内存缓存器
        if options.contains(.cacheMemoryOnly) {
            if let resp = self.cacheManager.valueInMemory(forKey: source.cacheKey) {
                return DataResponse(data: resp, source: .memory)
            }
            return nil
        }
        /// 检查是否存在于缓存中
        if let (data, source) = self.cacheManager.value(forKey: source.cacheKey) {
            /// 如果存在于缓存中, 只有两个来源 disk 或 memory
            return DataResponse(data: data, source: source == .disk ? .disk : .memory)
        }
        return nil
    }
}

// MARK: 缓存相关操作

@available(iOS 16.0, *)
public extension ImageLoader {
    func removeAllCache() throws {
        try self.cacheManager.removeAll()
    }

    func isCached(source: ImageSource) -> Bool {
        let cacheKey = source.cacheKey
        return self.cacheManager.isCached(forKey: cacheKey)
    }

    func remove(source: ImageSource) throws {
        let cacheKey = source.cacheKey
        try self.cacheManager.remove(forKey: cacheKey)
    }
}

// MARK: 网络操作

@available(iOS 16.0, *)
public extension ImageLoader {
    @discardableResult
    func url(
        _ source: ImageSource,
        options: LoaderOptions = [],
        progress: onProgress? = nil,
        completionHandler: @escaping onCompletionHandler
    ) -> ImageDownloadTask {
        let canceller = ImageDownloadTask()
        self.queue.async {
            /// 是否禁用缓存
            if options.contains(.disabledCache) == false {
                /// 是否忽略缓存
                if options.contains(.forceRefresh) != true {
                    /// 尝试从缓存中取数据
                    if let resp = self.loadDataFromCache(source: source, options: options) {
                        completionHandler(resp, nil)
                        return
                    }
                }

                /// 是否只从缓存中取数据
                if options.contains(.onlyFromCache) {
                    completionHandler(nil, .imageNotExisting)
                    return
                }
            }

            /// URL 是否是本地目录
            if source.url.isFileURL == true {
                do {
                    let data = try Data(contentsOf: source.url)
                    if options.contains(.noCacheLocalFile) == false, options.contains(.disabledCache) == false {
                        /// 如果资源响应来自于 local 应该将其存入内存中, 仅存内存, 不存磁盘
                        self.cacheManager.storeInMemory(value: data, forKey: source.cacheKey)
                    }
                    completionHandler(.init(data: data, source: .local), nil)
                    return
                } catch {
                    completionHandler(nil, .localFileLoadError(error))
                    return
                }
            }

            /// 从网络中获取数据
            let taskCanceller = self.network.urlRequest(with: URLRequest(url: source.url), progress: progress) { resp, error in
                if let error {
                    completionHandler(nil, .from(error))
                    return
                }
                if case .network = resp?.source, options.contains(.disabledCache) == false {
                    try? self.cacheManager.store(value: resp!.data, forKey: source.cacheKey)
                }
                completionHandler(resp, nil)
            }
            canceller.set(task: taskCanceller)
        }
        return canceller
    }

    /// 支持异步调用.
    func url(_ source: ImageSource, options: LoaderOptions = [], progress: onProgress? = nil) async throws -> DataResponse {
        /// 是否禁用缓存
        if options.contains(.disabledCache) == false {
            /// 是否忽略缓存
            if options.contains(.forceRefresh) == false {
                /// 尝试从缓存中取数据
                if let resp = self.loadDataFromCache(source: source, options: options) {
                    return resp
                }
            }

            /// 是否只从缓存中取数据
            if options.contains(.onlyFromCache) {
                throw WebImageError.imageNotExisting
            }
        }

        /// URL 是否是本地目录
        if source.url.isFileURL == true {
            do {
                let data = try Data(contentsOf: source.url)
                if options.contains(.noCacheLocalFile) == false, options.contains(.disabledCache) == false {
                    /// 如果资源响应来自于 local 应该将其存入内存中, 仅存内存, 不存磁盘
                    self.cacheManager.storeInMemory(value: data, forKey: source.cacheKey)
                }
                return .init(data: data, source: .local)
            } catch {
                throw WebImageError.localFileLoadError(error)
            }
        }

        /// 从网络获取数据.
        do {
            let resp = try await self.network.urlRequest(with: URLRequest(url: source.url), progress: progress)
            if case .network = resp.source, options.contains(.disabledCache) == false {
                try? self.cacheManager.store(value: resp.data, forKey: source.cacheKey)
            }
            return resp
        } catch {
            throw WebImageError.from(error as! NetworkError)
        }
    }

    /// 取消所有正在执行的任务
    func cancelAllTask() {
        self.network.cancelAllTask()
    }
}

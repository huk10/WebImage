//
//  Created by vvgvjks on 2024/6/26.
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

@available(iOS 16.0, *)
public class Network: @unchecked Sendable {
    private let lock = NSLock()
    private let urlSession: URLSession
    private let delegate: SessionDelegate
    private var ongoingTasks: [URLRequest: SessionDataTask] = [:]

    init(configuration: URLSessionConfiguration, concurrencyCount: Int = 5) {
        delegate = SessionDelegate(maxConcurrencyCount: concurrencyCount)
        urlSession = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
}

@available(iOS 16.0, *)
extension Network {
    /// 获取 SessionDataTask 如果不存在则创建一个新的.
    private func doRequest(with request: URLRequest) -> (Bool, SessionDataTask) {
        return lock.withLock {
            if let sesstionDataTask = self.ongoingTasks[request] {
                return (false, sesstionDataTask)
            }
            let dataTask = self.urlSession.dataTask(with: request)
            let sesstionDataTask = SessionDataTask(dataTask: dataTask)
            self.ongoingTasks[request] = sesstionDataTask
            /// 添加到队列中
            self.delegate.appendToQueue(dataTask: dataTask, sesstionDataTask: sesstionDataTask)
            /// dataTask 由 delegate 中的队列调度开始.
            /// dataTask.resume()
            return (true, sesstionDataTask)
        }
    }
}

@available(iOS 16.0, *)
public extension Network {
    @discardableResult
    func urlRequest(
        with request: URLRequest,
        progress: (@Sendable (Int64, Int64) -> Void)? = nil,
        completionHandler: @Sendable @escaping (DataResponse?, NetworkError?) -> Void
    ) -> DataTaskDelegate {
        let (isNetwork, sessionTask) = doRequest(with: request)
        return sessionTask.value(progress: progress) { data, error in
            if let error {
                completionHandler(nil, error)
            } else {
                completionHandler(data, nil)
            }
            if isNetwork {
                self.lock.withLock { self.ongoingTasks[request] = nil }
            }
        }
    }

    /// 支持使用 Task.cancel() 取消
    func urlRequest(with request: URLRequest, progress: ((Int64, Int64) -> Void)? = nil) async throws -> DataResponse {
        let (isNetwork, fetchTask) = doRequest(with: request)
        /// 请求结束后摘除 fetchTask
        defer {
            if isNetwork {
                lock.withLock { self.ongoingTasks[request] = nil }
            }
        }
        /// 依靠 fetchTask 内部处理取消状态
        return try await fetchTask.value(progress: progress)
    }

    /// 支持使用 Task.cancel() 取消
    @discardableResult
    func url(
        for url: URL,
        progress: (@Sendable (Int64, Int64) -> Void)? = nil,
        completionHandler: @Sendable @escaping (DataResponse?, NetworkError?) -> Void
    ) -> DataTaskDelegate {
        urlRequest(with: URLRequest(url: url), progress: progress, completionHandler: completionHandler)
    }

    /// 支持使用 Task.cancel() 取消
    func url(for url: URL, progress: ((Int64, Int64) -> Void)? = nil) async throws -> DataResponse {
        try await urlRequest(with: URLRequest(url: url), progress: progress)
    }

    /// 取消所有正在执行的任务
    func cancelAllTask() {
        delegate.cancelAllTask()
    }
}

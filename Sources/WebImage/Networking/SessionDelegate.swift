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

@available(iOS 16.0, *)
class SessionDelegate: NSObject {
    private var lock = NSLock()
    private let queue: OperationQueue
    private var ongoingTasks: [URLSessionTask: SessionDataTask] = [:]

    init(maxConcurrencyCount: Int) {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = maxConcurrencyCount
        operationQueue.qualityOfService = .userInitiated
        self.queue = operationQueue
    }

    /// 添加订阅者
    func appendToQueue(dataTask: URLSessionTask, sesstionDataTask: SessionDataTask) {
        self.lock.withLock {
            self.ongoingTasks[dataTask] = sesstionDataTask
            self.queue.addOperation(sesstionDataTask)
        }
    }
    
    /// 取消所有任务
    func cancelAllTask() {
        self.queue.cancelAllOperations()
    }
}

@available(iOS 16.0, *)
extension SessionDelegate: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let sessionTask = lock.withLock({ ongoingTasks[dataTask] }) {
            sessionTask.writeReceiveData(dataTask: dataTask, data: data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let sessionTask = lock.withLock({ ongoingTasks[task] }) else {
            fatalError("not found sessionTask")
        }
        self.lock.withLock { self.ongoingTasks[task] = nil }
        /// 如果存在 error 就一定是错误的, 存在错误的同时也是会存在 data 的
        if let error {
            /// 将取消错误转化成 FetchError.cancelled
            if let err = error as? URLError, err.code == URLError(.cancelled).code {
                return sessionTask.notify(error: .cancelled)
            }
            /// 其他错误只留下错误
            return sessionTask.notify(error: .urlSession((error as? URLError) ?? URLError(URLError.unknown)))
        }
        /// 默认的响应检查函数
        guard let statusCode = (task.response as? HTTPURLResponse)?.statusCode else {
            return sessionTask.notify(error: .badHTTPStatusCode(-1))
        }
        guard 200 ..< 300 ~= statusCode else {
            return sessionTask.notify(error: .badHTTPStatusCode(statusCode))
        }
        sessionTask.notify()
    }
}

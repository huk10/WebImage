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

/// 这个类继承了 `Operation` 它会交给 `OperationQueue` 进行调度执行.
/// 这负责 `URLSessionTask` 的执行和数据响应.
/// 它确保不会出现重复请求.
/// 调用链: ``SessionDelegate`` -> ``SessionDataTask`` -> ``DataTaskDelegate``
@available(iOS 16.0, *)
class SessionDataTask: Operation, Identifiable {
    // MARK: Operation 的重载实现

    /// Operation 的状态
    /// cancelled 状态由父类管理, 不再此处维护.
    private enum State: Int {
        case none
        case ready
        case finished
        case executing
    }

    /// 这几个属性不能使用 queue 不然可能死锁
    /// 因为内部会调用 willChangeValue 和 didChangeValue 这样外部接到通知, 在调用这几个计算属性就卡住了
    /// 可能是 willChangeValue 或者 didChangeValue 会触发外部调用计算属性, 计算属性加锁了会等待, 内部又再等待这两个方法结束就死锁了
    /// 这几个外部调用都是只读的, 只有内部会写, 内部写是在 queue 这把锁中, 而且状态都是上升的不会下降, 不需要加锁
    override var isAsynchronous: Bool { true }
    private var state = OSAllocatedUnfairLock<State>(initialState: .none)
    override var isFinished: Bool { self.state.withLock { $0 == .finished } }
    override var isExecuting: Bool { self.state.withLock { $0 == .executing } }
    /// 两个选择: 1, 是否不维护 isReady 的值, 默认为 true, 2, 在第一次调用 value 方法时修改其状态.
    override var isReady: Bool { self.state.withLock { $0 == .ready } && super.isReady }

    // MARK: 对外公开属性

    let task: URLSessionTask

    public let id: Int = sequence.value()

    // MARK: 内部私有属性

    private static let sequence = Sequence()

    /// 内部都是同步方法, 直接一把大锁得了, 减少复杂度, 以方法级别为颗粒度, 这样和 actor 没啥区别
    private let queue = NSLock()
    /// 写操作只有 didReceive 方法会写, didReceive 这个方法应该是有序调用, 不然这个方法就没法使用了.
    /// 而读数据只会在状态流转为完成后才读, 读写是没有冲突的无需加锁
    private var data = Data()
    // task 被取消会归于 error.
    private var error: NetworkError? = nil
    /// dataTask 调用是否成功.
    /// didCompleteWithError 方法总是在 didReceive 方法之后调用, 这意味着状态完成时 data 数据总是可用的
    private var isCompletion: Bool = false
    /// 用来标记重复请求的调用 ID
    private let callIdSequence = Sequence()
    /// 每次调用 value 方法都会返回一个 TaskCancelable 它有一个 cancel 方法, 可以使用它取消任务
    private var callbacks: [Int: DataTaskDelegate] = [:]

    init(dataTask: URLSessionTask) {
        self.task = dataTask
    }
}

// MARK: Operation 的方法实现

@available(iOS 16.0, *)
extension SessionDataTask {
    private func changeToReady() {
        willChangeValue(forKey: "isReady")
        self.state.withLock { $0 = .ready }
        didChangeValue(forKey: "isReady")
    }

    private func changeToFinished() {
        willChangeValue(forKey: "isFinished")
        self.state.withLock { $0 = .finished }
        didChangeValue(forKey: "isFinished")
    }

    private func changeToExecuting() {
        willChangeValue(forKey: "isExecuting")
        self.state.withLock { $0 = .executing }
        didChangeValue(forKey: "isExecuting")
    }

    override func start() {
        /// 这个取消状态由 Operation 父类管理,需要确保 cancel 方法正确调用 cancel, 这里只是检查.
        if isCancelled {
            /// 这个值为 true 时 self.task.cancel 方法就已经被调用过了.
            self.changeToFinished()
            return
        }
        /// `start` 方法有 `OperationQueue` 管理执行
        /// 也就是说此处 `isCompletion` 永远为 false error 永远为 nil
        /// 因为这个方法不会被重复执行?
        self.task.resume()
        self.changeToExecuting()
    }

    /// 此方法只在队列取消所有任务时才会调用
    /// 此方法调用时, 直接取消 self.dataTask 然后状态会自然流转到 failure
    override func cancel() {
        /// 这个取消状态由 Operation 父类管理
        super.cancel()
        self.task.cancel()
    }
}

// MARK: 对外公开方法

@available(iOS 16.0, *)
extension SessionDataTask {
    /// 添加一个回调方法在任务结束时调用
    /// 这个方法可能会被重复调用, 需要检查 dataTask 是否已完成.
    public func value(progress: onProgress? = nil, completionHandler: @escaping onCompletionHandler) -> DataTaskDelegate {
        return self.queue.withLock {
            let callId = self.callIdSequence.value()
            /// 如果任务已完成, 直接返回
            if self.isCompletion {
                completionHandler(.init(data: self.data, source: .shard), nil)
                return DataTaskDelegate(callId: callId)
            }
            /// 如果已存在错误, 则直接抛出
            /// 任务已取消其状态也会是错误
            if let error = self.error {
                completionHandler(nil, error)
                return DataTaskDelegate(callId: callId)
            }
            /// 第一次调用 value 方法时, 才真正去执行.
            if self.state.withLock({ $0 == .none }) {
                self.changeToReady()
            }
            /// 内部会处理取消状态
            let taskCancelable = DataTaskDelegate(callId: callId, dataTask: self, progress: progress) { data, error in
                if let error {
                    return completionHandler(nil, error)
                }
                completionHandler(data!, nil)
            }
            self.callbacks[callId] = taskCancelable
            return taskCancelable
        }
    }

    /// 异步化支持 `Task.cancel`
    /// 这个方法可能会被重复调用, 需要检查 dataTask 是否已完成.
    public func value(progress: onProgress? = nil) async throws -> DataResponse {
        /// 如果任务已完成, 直接返回
        if self.queue.withLock({ self.isCompletion }) {
            return .init(data: self.data, source: .shard)
        }
        /// 如果已存在错误, 则直接抛出
        if let error = self.queue.withLock({ self.error }) {
            throw error
        }

        /// 上面重复检查了, 避开下方的更复杂逻辑

        let deferredCanceller = DeferredCanceller()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                deferredCanceller.setObject(cancelable: self.value(progress: progress) { data, error in
                    if let error {
                        return continuation.resume(throwing: error)
                    }
                    continuation.resume(returning: data!)
                })
            }
        } onCancel: {
            deferredCanceller.cancel()
        }
    }

    /// 只有所有的回调都取消了才会真正取消任务
    /// 这里取消的时候, 可能此 `Operation` 还没有被 `OperationQueue` 执行, 此时在 `notify(error:)` 方法中不能设置状态为 `isFinished`
    /// 需要设置为 `isCancelled`, 不然会抛出警告: `went isFinished=YES without being started by the queue it is in.`
    /// 这个在 `notify(error:)` 方法中处理.
    public func cancel(_ callId: Int) {
        self.queue.withLock {
            self.callbacks[callId] = nil
            if self.callbacks.isEmpty {
                self.task.cancel()
            }
        }
    }
}

// MARK: 模块内私有方法

@available(iOS 16.0, *)
extension SessionDataTask {
    /// 写入响应数据
    func writeReceiveData(dataTask: URLSessionDataTask, data: Data) {
        self.data.append(data)
        let finishBytes = Int64(self.data.count)
        let totalBytes = dataTask.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown
        self.notify(completed: finishBytes, total: totalBytes)
    }

    /// 报告响应进度
    func notify(completed: Int64, total: Int64) {
        for callback in self.queue.withLock({ self.callbacks.values }) {
            callback.notify(completed: completed, total: total)
        }
    }

    /// 如果请求发生了错误或者被取消了
    /// 这个方法由 `URLSessionDataTask` 直接触发, 不会触发两次的, 这里不再检查状态.
    func notify(error: NetworkError) {
        let callbacks = self.queue.withLock {
            let result = self.callbacks.values
            self.error = error
            self.callbacks.removeAll()
            return result
        }
        for callback in callbacks {
            callback.notify(error: error)
        }

        /// 此处修复: `went isFinished=YES without being started by the queue it is in.` 警告.
        /// 原因是在 `Operation` 还没有被 `OperationQueue` 执行时, 不能将其状态设置为 `isFinished` 需要设置为 `isCancelled`
        /// 复现调用链: 对 `OperationQueue` 队列达到并发上限时, 马上调用新添加的 `Operation` 的 `cancel(_ callId: Int)` 方法
        if self.state.withLock({ $0 == .none || $0 == .ready }) {
            super.cancel()
        } else {
            self.changeToFinished()
        }
    }

    /// 如果请求正常成功结束
    /// 这个方法由 URLSessionDataTask 直接触发, 不会触发两次的, 这里不再检查状态.
    func notify() {
        let callbacks = self.queue.withLock {
            let result = self.callbacks.values
            self.isCompletion = true
            self.callbacks.removeAll()
            return result
        }
        self.changeToFinished()
        /// 如果没有 callbacks 是不会真正开始任务的. 上面加锁保证即使同步取消依旧会添加到 callbacks 中
        callbacks.first?.notify(data: .init(data: self.data, source: .network))
        for callback in callbacks {
            callback.notify(data: .init(data: self.data, source: .shard))
        }
    }
}

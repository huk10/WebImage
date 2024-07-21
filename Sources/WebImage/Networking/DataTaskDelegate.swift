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

/// 处理取消状态 - 有两个状态
/// - 已完成
/// - 等待完成
/// 这个类会暴露给外部使用的, 主要是给外部提供一个取消的方法.
@available(iOS 16.0, *)
public class DataTaskDelegate: @unchecked Sendable {
    enum State {
        case ready
        case finished
        case cancelled
    }

    public let callId: Int
    /// - 等待完成状态- 其必定存在
    /// - 已完成状态下- 不会使用到它
    let dataTask: SessionDataTask?

    /// 响应进度回调
    private let progress: onProgress?
    /// 响应完成回调
    private let completionHandler: onCompletionHandler?
    /// 内部状态.
    private let state = OSAllocatedUnfairLock<State>(initialState: .ready)

    public var isFinished: Bool { self.state.withLock { $0 != .ready } }
    public var isCancelled: Bool { self.state.withLock { $0 == .cancelled } }

    /// - 已完成
    init(callId: Int) {
        self.callId = callId
        self.dataTask = nil
        self.progress = nil
        self.completionHandler = nil
        self.state.withLock { $0 = .finished }
    }

    /// - 等待完成
    init(callId: Int, dataTask: SessionDataTask, progress: onProgress? = nil, completionHandler: @escaping onCompletionHandler) {
        self.callId = callId
        self.dataTask = dataTask
        self.progress = progress
        self.completionHandler = completionHandler
    }

    private func compareAndSwap(_ oldValue: State, _ newValue: State) -> Bool {
        self.state.withLock { _state in
            if _state != oldValue {
                return false
            }
            _state = newValue
            return true
        }
    }
}

// MARK: 对外暴露方法

/// 这些方法对外暴露, 也就是说这个方法可能会在主线程执行.
/// 需要注意要将外部传递的回调函数如: completionHandler 调度到其他线程执行.
@available(iOS 16.0, *)
public extension DataTaskDelegate {
    /// 取消任务
    func cancel() {
        /// 如果当前状态是 .ready 才能流转到 .cancelled
        if self.compareAndSwap(.ready, .cancelled) {
            callbackAsFunction {
                self.dataTask?.cancel(self.callId)
                self.completionHandler?(nil, .cancelled)
            }
        }
    }
}

// MARK: 模块内私有方法

/// 下面这些方法都是在内部使用的, 表示其已经在其他线程中了, 就无需使用 callbackAsFunction 调度了.
@available(iOS 16.0, *)
extension DataTaskDelegate {
    /// 通知调用方 Task 响应进度.
    func notify(completed: Int64, total: Int64) {
        /// 查询进度还每次都检查, 开销有些大
        if self.state.withLock({ $0 == .ready }) {
            self.progress?(completed, total)
        }
    }

    /// 通知调用方 Task 已成功响应
    func notify(data: DataResponse) {
        /// 如果当前状态是 .ready 就将状态流转到 .finished 并触发回调
        if self.compareAndSwap(.ready, .finished) {
            self.completionHandler?(data, nil)
        }
    }

    /// 通知调用方 Task 已失败
    func notify(error: NetworkError) {
        /// 如果当前状态是 .ready 就将状态流转到 .finished 并触发回调
        if self.compareAndSwap(.ready, .finished) {
            self.completionHandler?(nil, error)
        }
    }
}

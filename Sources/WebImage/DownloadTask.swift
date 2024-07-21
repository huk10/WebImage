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
public class ImageDownloadTask: @unchecked Sendable {
    private var delegate: DataTaskDelegate?
    private let isCancelled = OSAllocatedUnfairLock<Bool>(initialState: false)

    func set(task: DataTaskDelegate) {
        self.delegate = task
        if self.isCancelled.withLock({ $0 }) {
            task.cancel()
        }
    }
}

@available(iOS 16.0, *)
public extension ImageDownloadTask {
    /// 取消任务- 如果存在相同的请求, 则不会真正取消
    func cancel() {
        if self.isCancelled.withLock({ let result = $0; $0 = true; return result }) == false {
            self.delegate?.cancel()
        }
    }

    /// 重置任务优先级
    func resetTaskPriority() {
        guard let task = self.delegate?.dataTask?.task else {
            return
        }
        task.priority = URLSessionTask.defaultPriority
    }

    /// 增加任务优先级
    func increaseTaskPriority() {
        guard let task = self.delegate?.dataTask?.task else {
            return
        }
        task.priority = URLSessionTask.highPriority
    }

    /// 降低任务优先级
    func decreaseTaskPriority() {
        guard let task = self.delegate?.dataTask?.task else {
            return
        }
        task.priority = URLSessionTask.lowPriority
    }
}

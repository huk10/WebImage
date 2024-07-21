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
class DeferredCanceller: @unchecked Sendable {
    private let isCancelled = OSAllocatedUnfairLock<Bool>(initialState: false)
    private var cancelable: DataTaskDelegate?

    /// 标记已取消, 如果存在 taskCancelable 则触发, 否则 setObject 调用时触发
    func cancel() {
        self.isCancelled.withLock {
            $0 = true
            self.cancelable?.cancel()
        }
    }

    /// 如果已取消则直接触发, 否则就设置 taskCancelable 属性等 cancel 方法调用时触发
    func setObject(cancelable: DataTaskDelegate) {
        self.isCancelled.withLock {
            self.cancelable = cancelable
            if $0 == true {
                cancelable.cancel()
            }
        }
    }
}

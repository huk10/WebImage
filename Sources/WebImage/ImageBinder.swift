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
import SwiftUI

@available(iOS 16.0, *)
extension WebImage {
    class Binder: ObservableObject, @unchecked Sendable {
        /// 用来触发动画
        private(set) var loaded = false
        private(set) var loading = false
        private var dataTask: ImageDownloadTask?
        private(set) var progress: Progress = .init()

        /// 是否在请求中或者已请求完毕.
        var loadingOrSucceeded: Bool {
            loading || loadedImage != nil
        }

        /// 加载完成的图片内容, 它可能会是 onFialureImage.
        var loadedImage: UIImage? {
            willSet { objectWillChange.send() }
        }

        func start(context: Context) {
            /// 这里已经是主线程了
            guard let source = context.source else {
                return handleLoadedFailure(context: context, error: .emptySource)
            }
            loading = true
            progress = .init()
            dataTask = context.imageLoader.url(
                source,
                options: context.options,
                progress: { completed, total in
                    DispatchQueue.main.async {
                        self.updateProgress(completed: completed, total: total)
                        context.onProgressCallback?(self.progress)
                    }
                },
                completionHandler: { [weak self] resp, error in
                    guard let self else { return }
                    /// 曾经出现过死锁, 已修复 (锁不要锁外部回调方法, 锁尽量粒度小一些.)
                    ///
                    /// 这里需要使用 async 使用 sync 会与出现死锁.
                    /// 调用 cancel 时是在主线程调用的, 它内部使用了锁, 成功响应时会调用 notify 方法, 它会与 cancel 争抢锁.
                    ///
                    /// 线程X: URLSessionDataTask -> DataTaskDelegate -> notify -> completionHandler -> DispatchQueue.main.sync
                    ///
                    /// 主线程: main -> cancel -> DataTaskDelegate -> cancel
                    ///
                    /// 线程X 调用 DataTaskDelegate.notify 方法执行到此处, 此处等待主线程让出锁,
                    /// 而此时主线程正在调用 DataTaskDelegate.cancel 方法, 这个方法会等待 DataTaskDelegate.notify 这个方法.
                    DispatchQueue.main.async {
                        self.dataTask = nil
                        self.loading = false

                        if let error {
                            return self.handleLoadedFailure(context: context, error: error)
                        }

                        guard let resp, let uiImage = UIImage(data: resp.data) else {
                            return self.handleLoadedFailure(context: context, error: .decodingFailed)
                        }

                        self.loadedImage = uiImage
                        self.loaded = true
                        context.onSuccessCallback?(
                            .init(data: resp.data, source: .from(source: resp.source), uiImage: uiImage)
                        )
                    }
                }
            )
        }

        func cancel() {
            dataTask?.cancel()
            dataTask = nil
            loading = false
        }

        func restorePriorityOnAppear() {
            guard let dataTask = dataTask, loading == true else { return }
            dataTask.resetTaskPriority()
        }

        func reducePriorityOnDisappear() {
            guard let dataTask = dataTask, loading == true else { return }
            dataTask.decreaseTaskPriority()
        }

        // MARK: 内部私有方法

        private func updateProgress(completed: Int64, total: Int64) {
            progress.totalUnitCount = total
            progress.completedUnitCount = completed
            objectWillChange.send()
        }

        private func handleLoadedFailure(context: Context, error: WebImageError) {
            context.onFailureCallback?(error)
            if let uiImage = context.onFailureImage {
                loadedImage = uiImage
                loaded = true
            }
        }
    }
}

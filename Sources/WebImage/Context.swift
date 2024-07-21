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
    /// WebImage 需要的一些配置项集合
    class Context: @unchecked Sendable {
        let source: ImageSource?
        var imageLoader: ImageLoader
        /// 请求器的一些配置项
        var options: LoaderOptions = []
        /// 是否在 disappear 时取消图片加载任务
        var cancelOnDisappear: Bool = false
        /// 是否在 disapper 时降低图片加载人物的优先级 ``URLSessionTask.priority``
        /// 需注意如果存在相同的图片[URL相等] 则它们会共用一个 ``URLSessionDataTask``
        /// 这会导致所有的优先级都被修改, 建议使用 `cancelOnDisappear` 配置
        var reducePriorityOnDisappear: Bool = true
        /// 加载失败时显示的视图
        var onFailureImage: UIImage?
        /// 加载中的视图, 如果 onFailureImage 为 nil 则失败时依旧显示此视图
        var placeholder: ((Progress) -> AnyView)?
        /// 对 Image 进行修饰
        var configurations: [(Image) -> Image] = []
        /// 跟踪加载状态
        var onSuccessCallback: ((ImageResult) -> Void)?
        var onFailureCallback: ((WebImageError) -> Void)?
        var onProgressCallback: ((Progress) -> Void)?

        /// 支持可选传参, 如果传入的是nil, 在渲染时会直接渲染 failureImage
        init(source: ImageSource?, imageLoader: ImageLoader = .shard) {
            self.source = source
            self.imageLoader = imageLoader
        }
    }
}

@available(iOS 16.0, *)
extension WebImage.Context: Hashable {
    static func == (lhs: WebImage.Context, rhs: WebImage.Context) -> Bool {
        lhs.source == rhs.source
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(source?.url)
    }
}

@available(iOS 16.0, *)
public extension WebImage {
    func setImageLoader(_ loader: ImageLoader) -> Self {
        context.imageLoader = loader
        return self
    }

    func onlyFromCache() -> Self {
        context.options.insert(.onlyFromCache)
        return self
    }

    func cacheMemoryOnly() -> Self {
        context.options.insert(.cacheMemoryOnly)
        return self
    }

    func forceRefresh() -> Self {
        context.options.insert(.forceRefresh)
        return self
    }

    func diskCacheSynchronized() -> Self {
        context.options.insert(.diskCacheSynchronized)
        return self
    }

    func onFailureImage(_ uiImage: UIImage) -> Self {
        context.onFailureImage = uiImage
        return self
    }

    func cancelOnDisappear(_ enable: Bool) -> Self {
        context.cancelOnDisappear = enable
        return self
    }

    func placeholder<P: View>(@ViewBuilder _ content: @escaping (Progress) -> P) -> Self {
        context.placeholder = { progress in
            AnyView(content(progress))
        }
        return self
    }

    func placeholder<P: View>(@ViewBuilder _ content: @escaping () -> P) -> Self {
        placeholder { _ in content() }
    }

    func configure(_ block: @escaping (Image) -> Image) -> Self {
        context.configurations.append(block)
        return self
    }

    func reducePriorityOnDisappear(_ enable: Bool) -> Self {
        context.reducePriorityOnDisappear = enable
        return self
    }

    func onProgress(_ block: @escaping (Progress) -> Void) -> Self {
        context.onProgressCallback = block
        return self
    }

    func onSuccess(_ block: @escaping (ImageResult) -> Void) -> Self {
        context.onSuccessCallback = block
        return self
    }

    func onFailure(_ block: @escaping (WebImageError) -> Void) -> Self {
        context.onFailureCallback = block
        return self
    }
}

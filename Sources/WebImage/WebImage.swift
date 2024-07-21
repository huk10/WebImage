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
@_exported import BlurHash

@available(iOS 16.0, *)
public struct WebImage: View {
    var context: Context

    init(context: Context) {
        self.context = context
    }

    /// 这里的 `context` 是应用修饰符之后的 `context`
    public var body: some View {
        ImageRender(context: context).id(context)
    }
}

/// 只能使用静态方法进行初始化
@available(iOS 16.0, *)
public extension WebImage {
    
    /// - Parameters:
    ///   - url: 支持本地文件
    ///   - cacheKey: 用于内存缓存的`key`和磁盘缓存的`文件名称`
    /// - Returns: ``WebImage``
    static func url(_ atPath: String, cacheKey: String? = nil) -> Self {
        Self(context: Context(source: ImageSource(atPath: atPath, cacheKey: cacheKey)))
    }

    static func url(_ url: URL?, cacheKey: String? = nil) -> Self {
        Self(context: Context(source: ImageSource(url: url, cacheKey: cacheKey)))
    }

    static func source(_ source: ImageSource) -> Self {
        Self(context: Context(source: source))
    }
}

/// 支持 Image 的一些修饰符
@available(iOS 16.0, *)
public extension WebImage {
    func renderingMode(_ renderingMode: Image.TemplateRenderingMode?) -> Self {
        configure { $0.renderingMode(renderingMode) }
    }

    func resizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: Image.ResizingMode = .stretch) -> Self {
        configure { $0.resizable(capInsets: capInsets, resizingMode: resizingMode) }
    }

    func antialiased(_ isAntialiased: Bool) -> Self {
        configure { $0.antialiased(isAntialiased) }
    }

    func interpolation(_ interpolation: Image.Interpolation) -> Self {
        configure { $0.interpolation(interpolation) }
    }

    func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> Self {
        configure { $0.symbolRenderingMode(mode) }
    }

    @available(iOS 17.0, *)
    func allowedDynamicRange(_ range: Image.DynamicRange?) -> Self {
        configure { $0.allowedDynamicRange(range) }
    }
}

@available(iOS 16.0, *)
#Preview {
    HStack {
        let url = "http://192.168.50.2:8045/assets/photo/795d411eb801000.jpg"
        WebImage.url(URL(string: url)!)
            .cacheMemoryOnly()
            .forceRefresh()
            .onFailure { error in
                print("error: \(error)")
            }
            .onProgress { value in
                print("progress: \(value.fractionCompleted)")
            }
            .onSuccess { data in
                print("data.count: \(data.data.count)")
            }
            .resizable()
            .scaledToFit()
            .frame(width: 200, height: 200)
            .border(.red)
    }
}

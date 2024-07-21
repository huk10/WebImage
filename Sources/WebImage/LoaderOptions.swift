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

public struct LoaderOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// 只从缓存中取数据
    public static let onlyFromCache = LoaderOptions(rawValue: 1 << 0)
    /// 只使用内存缓存
    public static let cacheMemoryOnly = LoaderOptions(rawValue: 1 << 1)
    /// 刷新缓存
    public static let forceRefresh = LoaderOptions(rawValue: 1 << 2)
    /// 磁盘缓存同步写入
    public static let diskCacheSynchronized = LoaderOptions(rawValue: 1 << 3)
    /// 禁止缓存本地文件
    public static let noCacheLocalFile = LoaderOptions(rawValue: 1 << 4)
    /// 禁止缓存
    public static let disabledCache = LoaderOptions(rawValue: 1 << 5)

}


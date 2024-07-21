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

typealias onProgress = (Int64, Int64) -> Void
typealias onCompletionHandler = (DataResponse?, NetworkError?) -> Void

public enum NetworkError: Error {
    case cancelled
    case urlSession(URLError)
    case badHTTPStatusCode(Int)
}

public struct DataResponse: Sendable {
    public let data: Data
    public let source: DataSource

    public enum DataSource: Sendable {
        /// 来自磁盘
        case disk
        /// 来自内存
        case memory
        /// 来自本地文件
        case local
        /// 来自同一个 network 的后续请求, 上个 network 请求还未结束, 就又来了一个相同的 network 请求.
        case shard
        /// 来自磁盘
        case network
    }
}


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

public enum CacheError: Error {
    case fileSystemError(Error)
    case createCacheDirectory(Error)
    case readDiskFileData(URL, Error)
    case writeToDiskFileData(URL, Error)
    case cacheDirectoryDoesNotExist(URL)
}

extension CacheError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .createCacheDirectory(let err):
            "create cache directory throw error: \(err.localizedDescription)."
        case .writeToDiskFileData(let url, let err):
            "Write to disk file throw error: \(err.localizedDescription) url: \(url.path)"
        case .readDiskFileData(let url, let err):
            "Read disk file throw error: \(err.localizedDescription) url: \(url.path)"
        case .fileSystemError(let err):
            "File system throws an error:\(err.localizedDescription)."
        case .cacheDirectoryDoesNotExist(let url):
            "Cache directory does not exist \(url.path)"
        }
    }
}

extension CacheError: CustomNSError {
    public static let errorDomain: String = "com.vvgvjks.moss.Caches"
    public var errorCode: Int {
        switch self {
        case .createCacheDirectory: 1101
        case .writeToDiskFileData: 1102
        case .readDiskFileData: 1103
        case .fileSystemError: 1104
        case .cacheDirectoryDoesNotExist: 1105
        }
    }
}

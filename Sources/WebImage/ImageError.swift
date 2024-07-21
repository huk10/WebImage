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

public enum WebImageError: Error {
    case emptySource
    case emptyRequest
    case taskCancelled
    case decodingFailed
    case imageNotExisting
    case urlSessionError(URLError)
    case invalidHTTPStatusCode(Int)
    case invalidRequest(URLRequest)
    case localFileLoadError(Error)
    case invalidURLResponse(Error)
}

extension WebImageError {
    static func from(_ error: NetworkError) -> Self {
        switch error {
        case .cancelled: .taskCancelled
        case .badHTTPStatusCode(let code): .invalidHTTPStatusCode(code)
        case .urlSession(let err): .urlSessionError(err)
        }
    }
}

@available(iOS 15, *)
extension WebImageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptySource:
            return String(localized: "The image source is empty.", comment: "Empty Source")
        case .emptyRequest:
            return String(localized: "The request is empty.", comment: "Empty Request")
        case .taskCancelled:
            return String(localized: "The image loading task was cancelled.", comment: "Task Cancelled")
        case .imageNotExisting:
            return String(localized: "The image does not exist in cache.", comment: "Image Not Exist In Cache")
        case .decodingFailed:
            return String(localized: "Failed to decode the image content.", comment: "Decoding Failed")
        case .urlSessionError(let error):
            return String(localized: "URL session error occurred: \(error.localizedDescription)", comment: "URL Session Error")
        case .invalidHTTPStatusCode(let code):
            return String(localized: "Received an invalid HTTP status code: \(code).", comment: "Invalid HTTP Status Code")
        case .invalidRequest(let request):
            return String(localized: "The request is invalid: \(request.url?.absoluteString ?? "").", comment: "Invalid Request")
        case .localFileLoadError(let error):
            return String(localized: "Failed to load local file data: \(error.localizedDescription).", comment: "Local File Load Error")
        case .invalidURLResponse(let error):
            return String(localized: "Invalid URL response: \(error.localizedDescription).", comment: "Invalid URL Response")
        }
    }
}

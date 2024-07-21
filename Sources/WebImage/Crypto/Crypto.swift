//
//  Created by vvgvjks on 2024/7/21.
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
import CryptoKit

public func hex(_ string: [UInt8]) -> String {
    return string.compactMap { String(format: "%02x", $0) }.joined()
}

public func md5(_ input: Data) -> Data {
    let hashed = Insecure.MD5.hash(data: input)
    return Data(hashed)
}

public func sha1(_ input: Data) -> Data {
    let hashed = Insecure.SHA1.hash(data: input)
    return Data(hashed)
}

public func sha256(_ input: Data) -> Data {
    return Data(SHA256.hash(data: input))
}

public func sha384(_ input: Data) -> Data {
    return Data(SHA384.hash(data: input))
}

public func sha512(_ input: Data) -> Data {
    return Data(SHA512.hash(data: input))
}

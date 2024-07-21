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

@testable import WebImage
import XCTest

@available(iOS 16.0, *)
final class NetworkTests: XCTestCase {
    typealias RequestHandler = (URLRequest) throws -> (HTTPURLResponse, Data)

    var testResponseText: String {
        """
        {
            "id": 2,
            "date": 1650208156,
            "sha1": "95ba590d251880e8d122e529b12743e37e862408",
            "url": "http://192.168.50.2:8045/assets/photo/795d411cf001000.jpg",
            "mimeType": "image/jpeg",
            "fileSize": 141485,
            "width": 853,
            "height": 1280,
            "ext": ".jpg"
        }
        """
    }

    func testRequestHnadler(statusCode: Int = 200, error: Error? = nil) -> RequestHandler {
        {
            req in
            if let error {
                throw error
            }
            let response = HTTPURLResponse(
                url: req.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = self.testResponseText.data(using: .utf8)!
            return (response, data)
        }
    }

    var sessionConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockDelayRequest.self]
        return configuration
    }

    var testEndpoint = URL(string: "https://127.0.0.1:8080/photo/list")!

    override func tearDown() {
        MockDelayRequest.requestHandler = nil
        super.tearDown()
    }

    var fetch: ImageLoader {
        ImageLoader(
            configuration: self.sessionConfiguration,
            concurrentCount: 2,
            memoryCountLimit: 0,
            memoryTotalCostLimit: 0,
            diskCacheStorageDirectory: .cachesDirectory
        )
    }

    /// 测试正常场景
    func testFetchStatusCode200() async {
        let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
        do {
            MockDelayRequest.simulatedDelay = 100
            MockDelayRequest.requestHandler = self.testRequestHnadler(statusCode: 200)
            let resp = try await fetch.url(for: self.testEndpoint)
            XCTAssertEqual(resp.source, .network, "response error")
            let dataText = String(decoding: resp.data, as: UTF8.self)
            XCTAssertEqual(dataText, self.testResponseText, "Response data is incomplete")
        } catch {
            XCTFail("test error: \(error)")
        }
    }

    /// 测试错误码错误场景.
    func testFetchStatusCodeError() async {
        let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
        for code in [100, 199, 300, 302, 304, 404, 500] {
            do {
                MockDelayRequest.simulatedDelay = 50
                MockDelayRequest.requestHandler = self.testRequestHnadler(statusCode: code)
                let _ = try await fetch.url(for: self.testEndpoint)
                XCTFail("An error should be thrown")
            } catch {
                if case .badHTTPStatusCode(code) = error as? NetworkError {
                    XCTAssertTrue(true)
                } else {
                    XCTFail("unknun error: \(error)")
                }
            }
        }
    }

    /// 测试响应错误场景
    func testFetchResponseError() async throws {
        do {
            let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
            MockDelayRequest.simulatedDelay = 100
            MockDelayRequest.requestHandler = self.testRequestHnadler(error: URLError(.badServerResponse))
            let _ = try await fetch.url(for: self.testEndpoint)
            XCTFail("An error should be thrown")
        } catch {
            if case .urlSession(let err) = error as? NetworkError, err.code == URLError(.badServerResponse).code {
                XCTAssertTrue(true)
            } else {
                XCTFail("unknun error: \(error)")
            }
        }
    }

    /// 测试异步同步取消
    func testFetchSyncCancel() async throws {
        let task = Task {
            do {
                let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
                MockDelayRequest.simulatedDelay = 100
                MockDelayRequest.requestHandler = self.testRequestHnadler()
                let _ = try await fetch.url(for: self.testEndpoint)
                XCTFail("An error should be thrown")
            } catch {
                var flag = false
                if case .cancelled = error as? NetworkError {
                    flag = true
                }
                return XCTAssertTrue(flag, "unknown error \(error)")
            }
        }
        task.cancel()
        await task.value
    }

    /// 测试异步取消
    func testFetchAsyncCancel() async throws {
        let task = Task {
            do {
                let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
                MockDelayRequest.simulatedDelay = 2000
                MockDelayRequest.requestHandler = self.testRequestHnadler()
                let _ = try await fetch.url(for: self.testEndpoint)
                XCTFail("An error should be thrown")
            } catch {
                var flag = false
                if case .cancelled = error as? NetworkError {
                    flag = true
                }
                return XCTAssertTrue(flag, "unknown error \(error)")
            }
        }
        let startTime = Date()
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(200)) {
            task.cancel()
        }
        await task.value
        let endTime = Date()
        if endTime.timeIntervalSince1970 - startTime.timeIntervalSince1970 > 500 {
            XCTFail()
        }
    }

    /// 测试并发调用-只存在一个网络请求.
    func testConcurrentCall() async {
        let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
        let count = 10
        let task = Task {
            var tasks = [Task<DataResponse.DataSource?, Never>]()
            for _ in 0 ..< count {
                let t = Task<DataResponse.DataSource?, Never> {
                    do {
                        MockDelayRequest.simulatedDelay = 300
                        MockDelayRequest.requestHandler = self.testRequestHnadler()
                        let resp = try await fetch.url(for: self.testEndpoint)
                        return resp.source
                    } catch {
                        XCTFail("unknown error \(error)")
                        return nil
                    }
                }
                tasks.append(t)
            }
            var result: [DataResponse.DataSource?] = []
            for t in tasks {
                let v = await t.value
                result.append(v)
            }
            return result
        }
        let values = await task.value
        if values.isEmpty {
            XCTFail()
        }
        if values.filter({ $0 == .network }).count != 1 {
            XCTFail()
        }
        if values.filter({ $0 == .shard }).count != count - 1 {
            XCTFail()
        }
    }

    /// 测试并发调用-然后取消全部任务
    func testConcurrentAndCancelAll() async {
        let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
        let count = 10
        let startTime = Date()
        let responseDelay = 2000
        let task = Task {
            await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
                for _ in 0 ..< count {
                    group.addTask {
                        do {
                            MockDelayRequest.simulatedDelay = responseDelay
                            MockDelayRequest.requestHandler = self.testRequestHnadler()
                            let _ = try await fetch.url(for: self.testEndpoint)
                            return false
                        } catch {
                            guard case .cancelled = error as? NetworkError else {
                                return false
                            }
                            return true
                        }
                    }
                }
                return await group
                    .compactMap { $0 }
                    .reduce(into: []) { prev, curr in prev.append(curr) }
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(200)) {
            fetch.cancelAllTask()
        }
        let values = await task.value
        let endTime = Date()
        if endTime.timeIntervalSince1970 - startTime.timeIntervalSince1970 > 400 {
            XCTFail()
        }
        if values.isEmpty {
            XCTFail()
        }
        if values.filter({ $0 == true }).count != count {
            XCTFail()
        }
    }

    /// 测试并发调用-然后取消任务
    func testConcurrentAndCancel() async {
        let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
        let count = 10
        let startTime = Date()
        let responseDelay = 2000
        let task = Task {
            await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
                for _ in 0 ..< count {
                    group.addTask {
                        do {
                            MockDelayRequest.simulatedDelay = responseDelay
                            MockDelayRequest.requestHandler = self.testRequestHnadler()
                            let _ = try await fetch.url(for: self.testEndpoint)
                            return false
                        } catch {
                            guard case .cancelled = error as? NetworkError else {
                                return false
                            }
                            return true
                        }
                    }
                }
                return await group
                    .compactMap { $0 }
                    .reduce(into: []) { prev, curr in prev.append(curr) }
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(200)) {
            task.cancel()
        }
        let values = await task.value
        let endTime = Date()
        if endTime.timeIntervalSince1970 - startTime.timeIntervalSince1970 > 500 {
            XCTFail()
        }
        if values.isEmpty {
            XCTFail()
        }
        if values.filter({ $0 == true }).count != count {
            XCTFail()
        }
    }

    /// 测试回调方式调用
    func testCallbackCall() {
        let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
        let responseDelay = 500
        let exp = expectation(description: "--")
        MockDelayRequest.simulatedDelay = responseDelay
        MockDelayRequest.requestHandler = self.testRequestHnadler()
        fetch.url(for: self.testEndpoint) { resp, err in
            XCTAssertTrue(resp?.source == .network)
            XCTAssertTrue(resp?.data.count == self.testResponseText.data(using: .utf8)?.count)
            XCTAssertTrue(err == nil)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }

    /// 测试回调方式调用 - 立即取消
    func testCallbackCallAndCancel() {
        let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
        let responseDelay = 500
        let exp = expectation(description: "--")
        MockDelayRequest.simulatedDelay = responseDelay
        MockDelayRequest.requestHandler = self.testRequestHnadler()
        let tc = fetch.url(for: self.testEndpoint) { resp, err in
            exp.fulfill()
            XCTAssertTrue(resp == nil)
            guard case .cancelled = err else {
                XCTFail()
                return
            }
        }
        tc.cancel()
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }

    /// 测试回调方式调用 - 异步取消
    func testCallbackAsyncCancel() {
        let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
        let responseDelay = 500
        let exp = expectation(description: "--")
        MockDelayRequest.simulatedDelay = responseDelay
        MockDelayRequest.requestHandler = self.testRequestHnadler()
        let tc = fetch.url(for: self.testEndpoint) { resp, err in
            exp.fulfill()
            XCTAssertTrue(resp == nil)
            guard case .cancelled = err else {
                XCTFail()
                return
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(200)) {
            tc.cancel()
        }
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }

    /// 测试回调方式调用 - 异步取消
    func testCallbackBatchAsyncCancelAll() {
        let fetch = Network(configuration: sessionConfiguration, concurrencyCount: 2)
        let responseDelay = 500
        MockDelayRequest.simulatedDelay = responseDelay
        MockDelayRequest.requestHandler = self.testRequestHnadler()

        for _ in 0 ..< 10 {
            let exp = expectation(description: "--")
            fetch.url(for: self.testEndpoint) { resp, err in
                exp.fulfill()
                XCTAssertTrue(resp == nil)
                guard case .cancelled = err else {
                    XCTFail()
                    return
                }
            }
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(200)) {
            fetch.cancelAllTask()
        }
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }

    /// 同步方式使用-测试进度
    /// 0.25 0.5 1.0
    func testSyncProgress() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockProgressResponse.self]
        let fetch = Network(configuration: configuration, concurrencyCount: 2)
        let exp = expectation(description: "--")
        let count = AtomicInt(value: 0)
        fetch.url(for: self.testEndpoint) { completed, total in
            count.increment()
            let value = Double(completed) / Double(total)
            if count.value == 1 {
                XCTAssertEqual(value, 0.25)
            }
            if count.value == 2 {
                XCTAssertEqual(value, 0.5)
            }
            if count.value == 3 {
                XCTAssertEqual(value, 1.0)
            }
        } completionHandler: { _, err in
            XCTAssertTrue(err == nil)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }

    /// 异步方式使用-测试进度
    /// 0.25 0.5 1.0
    func testAsyncProgress() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockProgressResponse.self]
        let fetch = Network(configuration: configuration, concurrencyCount: 2)

        let count = AtomicInt(value: 0)
        let _ = try await fetch.url(for: self.testEndpoint) { completed, total in
            count.increment()
            let value = Double(completed) / Double(total)
            if count.value == 1 {
                XCTAssertEqual(value, 0.25)
            }
            if count.value == 2 {
                XCTAssertEqual(value, 0.5)
            }
            if count.value == 3 {
                XCTAssertEqual(value, 1.0)
            }
        }
    }
}

class AtomicInt: @unchecked Sendable {
    private var _value: Int
    private let lock = NSLock()
    init(value: Int) {
        self._value = value
    }

    var value: Int {
        self.lock.withLock { self._value }
    }

    func increment() {
        self.lock.withLock { self._value += 1 }
    }
}

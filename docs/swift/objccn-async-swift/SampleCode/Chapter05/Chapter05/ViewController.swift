//
//  ViewController.swift
//  Chapter05
//
//  Created by Wang Wei on 2021/07/22.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        Task {
            do {
                // 使用 session.bytes
                // try await sessionBytes()
                
                // 通过前几个字节判断文件类型
                // try await checkImageFormat()
                
                // 按照 UTF8 字符的 line 获取
                // try await sessionLines()

                // await notifications()
            } catch {
                print(error)
            }
        }
    }

    func sessionBytes() async throws {
        let url = URL(string: "https://example.com")!
        let session = URLSession.shared
        let (bytes, _) = try await session.bytes(from: url)
        for try await byte in bytes {
            print(byte, terminator: ",")
        }
    }
    
    func checkImageFormat() async throws {
        let url = URL(string: "https://objccn.io/images/books/async-swift/cover.png")!
        let session = URLSession.shared
        let (bytes, _) = try await session.bytes(from: url)
        var pngHeader: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
        for try await byte in bytes.prefix(8) {
            if byte != pngHeader.removeFirst() {
                print("Not PNG")
                return
            }
        }
        print("PNG")
    }
    
    func sessionLines() async throws {
        let url = URL(string: "https://example.com")!
        let session = URLSession.shared
        let (bytes, _) = try await session.bytes(from: url)
        for try await line in bytes.lines {
            print(line)
        }
    }
    
    func notifications() async {
        let backgroundNotifications = NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification, object: nil)
        for await notification in backgroundNotifications {
            print(notification)
        }
    }
    
    func asyncMethod() async throws -> Bool {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        return true
    }
    
    func syncMethod() async throws {
        let task = Task {
            try await asyncMethod()
        }
        let result = try await task.value
        print(result)
    }
}

extension ViewController: URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse
    ) async -> URLSession.ResponseDisposition
    {
        guard let scheme = response.url?.scheme, scheme.starts(with: "https") else {
            return .cancel
        }
        
        return .allow
    }
}

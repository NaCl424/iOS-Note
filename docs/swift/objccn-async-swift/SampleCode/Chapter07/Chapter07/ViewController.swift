//
//  ViewController.swift
//  Chapter07
//
//  Created by Wang Wei on 2021/08/12.
//

import UIKit

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async {
        await withUnsafeContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                continuation.resume()
            }
        }
    }
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        Task {
            // await SingleCancel().start()
            // await CancelReturnHandling().start()
            // await CancelThrowHandling().start()
            // await TaskTreeCancel().start()
            // try await URLSessionCancel().start()
            // await CancelHandler().start()
            // await AsyncObserve().start()
            // await AsyncSequenceCancel().start()
            // await ImplicitAwait().start()
        }
        
    }


}

struct SingleCancel {
    func start() async {
        let t = Task {
            let value = await work()
            print(value)
        }
        
        await Task.sleep(seconds: 2.5)
        t.cancel()
    }
    
    func work() async -> String {
        var s = ""
        for c in "Hello" {
            // Simulate some heavy work...
            await Task.sleep(seconds: 1.0)
            print("Append: \(c), cancelled: \(Task.isCancelled)")
            s.append(c)
        }
        
        return s
    }
}

struct CancelReturnHandling {
    func start() async {
        let t = Task {
            let value = await work()
            print(value)
        }
        
        await Task.sleep(seconds: 2.5)
        t.cancel()
        
    }
    
    func work() async -> String {
        var s = ""
        for c in "Hello" {
            // 检查取消状态
            guard !Task.isCancelled else {
                return s
            }
            
            await Task.sleep(seconds: 1.0)
            print("Append: \(c)")
            s.append(c)
        }
        
        return s
    }
}

struct CancelThrowHandling {
    func start() async {
        let t = Task {
            do {
                let value = try await work()
                print(value)
            } catch is CancellationError {
                print("任务被取消")
            } catch {
                print("其他错误：\(error)")
            }
        }
        
        await Task.sleep(seconds: 2.5)
        t.cancel()
    }
    
    func work() async throws -> String {
        var s = ""
        for c in "Hello" {
            // 检查取消状态
            try Task.checkCancellation()
            
            await Task.sleep(seconds: 1.0)
            print("Append: \(c)")
            s.append(c)
        }
        
        return s
    }
}

struct MyError: Error {}

struct TaskTreeCancel {
    func start() async {
        let autoCancel = true
        let t = Task {
            do {
                let value: String = try await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask {
                        try await withThrowingTaskGroup(of: String.self) { inner in
                            inner.addTask {
                                try await work("Hello", autoCancel: autoCancel)
                            }
                            inner.addTask {
                                try await work("World!", autoCancel: autoCancel)
                            }
                            
                            // 1. Cancel inner
                            await Task.sleep(seconds: 2.5)
                            inner.cancelAll()
                            
                            return try await inner.reduce([]) { $0 + [$1] }.joined(separator: " ")
                        }
                    }
                    
                    group.addTask {
                        try await work("Swift Concurrency", autoCancel: autoCancel)
                    }
                    
                    return try await group.reduce([]) { $0 + [$1] }.joined(separator: " ")
                }
                print(value)
            } catch {
                print(error)
            }
        }
        
        // 2. Cancel root task
        await Task.sleep(seconds: 2.5)
        t.cancel()
    }
    
    func work(_ text: String, autoCancel: Bool) async throws -> String {
        var s = ""
        for c in text {
            // 检查取消状态
            if Task.isCancelled {
                print("Cancelled: \(text)")
            }
            if !autoCancel {
                try Task.checkCancellation()
                await Task.sleep(seconds: 1.0)
            } else {
                try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            }
            
            print("Append: \(c)")
            s.append(c)
        }
        print("Done: \(s)")
        return s
    }
}

struct URLSessionCancel {
    func start() async throws {
        let t = Task {
            do {
                let (data, _) = try await
                    URLSession.shared.data(from: URL(string: "https://example.com")!, delegate: nil)
                print(data.count)
            } catch {
                print(error)
            }
        }
        try await Task.sleep(nanoseconds: 100)
        t.cancel()
    }
}

struct CancelHandler {
    func start() async {
        let t = Task {
            do {
                try await withTaskCancellationHandler {
                    try Task.checkCancellation()
                    await Task.sleep(seconds: 1.0)
                    try Task.checkCancellation()
                    await Task.sleep(seconds: 1.0)
                    try Task.checkCancellation()
                    await Task.sleep(seconds: 1.0)
                } onCancel: {
                    print("Cancel happened: \(Date())")
                }
            } catch {
                print("Error happened: \(Date())")
                print(error)
            }
            
        }
        await Task.sleep(seconds: 1.5)
        t.cancel()
    }
}

struct AsyncObserve {
    
    class Observer {
        
        enum E: Error {
            case userStopped
        }
        
        var block: ((String?, Error?) -> Void)?
        
        func start() { print("Started...") }
        func stop() {
            print("Stopped...")
            block?(nil, E.userStopped)
            block = nil
        }
        
        func waitForNextValue(_ block: @escaping (String?, Error?) -> Void) {
            self.block = block
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                self.block?("Hello", nil)
                self.block = nil
            }
        }
    }
    
    func start() async {
        let t = Task {
            do {
                let value = try await asyncObserve()
                print(value)
            } catch {
                print(error)
            }
        }
        await Task.sleep(seconds: 1.0)
        t.cancel()
    }
    
    func asyncObserve() async throws -> String {
        let observer = Observer()
        return try await withTaskCancellationHandler {
            observer.start()
            return try await withUnsafeThrowingContinuation { continuation in
                observer.waitForNextValue { value, error in
                    if let value = value {
                        continuation.resume(returning: value)
                    } else {
                        continuation.resume(throwing: error!)
                    }
                }
            }
        } onCancel: {
            observer.stop()
        }
    }
}

struct AsyncSequenceCancel {
    func start() async {
        let t = Task {
            let s = AsyncFibonacciSequence()
            do {
                for try await v in s {
                    print(v)
                }
            } catch {
                print(error)
            }
            
        }
        await Task.sleep(seconds: 4.0)
        t.cancel()
    }
}

struct AsyncFibonacciSequence: AsyncSequence {
    typealias Element = Int
    struct AsyncIterator: AsyncIteratorProtocol {
        
        var currentIndex = 0
        
        mutating func next() async throws -> Int? {
            defer { currentIndex += 1 }
            
            try Task.checkCancellation()
            
            // or
            // if Task.isCancelled {
            //    return nil
            // }
            
            return try await loadFibNumber(at: currentIndex)
        }
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        .init()
    }
}

func loadFibNumber(at index: Int) async throws -> Int {
    // Some API...
    await Task.sleep(seconds: 1.0)
    return fibNumber(at: index)
}

func fibNumber(at index: Int) -> Int {
    if index == 0 { return 0 }
    if index == 1 { return 1 }
    return fibNumber(at: index - 2) + fibNumber(at: index - 1)
}

struct ImplicitAwait {
    func start() async {
        let t = Task {
            do {
                try await withThrowingTaskGroup(of: Int.self) { group in
                    group.addTask { try await work() }
                    group.addTask { try await work() }
                    try await group.waitForAll()
                }
            } catch {
                print(error)
            }
        }
        await Task.sleep(seconds: 1.0)
        t.cancel()
    }
    
    func work() async throws -> Int {
        print("Start")
        try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
        print("Done")
        return 1
    }
}

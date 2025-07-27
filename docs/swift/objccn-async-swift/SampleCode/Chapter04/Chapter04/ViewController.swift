//
//  ViewController.swift
//  Chapter04
//
//  Created by Wang Wei on 2021/07/15.
//

import UIKit
import Combine

class ViewController: UIViewController {
    
    var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        Task {
            do {
                // 同步
                // syncFib()
                
                // 基于 class 的单次异步
                // try await classAsyncFib()
                
                // 使用 map 等操作序列
                // try await transformAsyncFib()
                
                // Side effect
                // try await debugFib()
                
                // Timer 转换到 AsyncStream
                // await timerByWrapping()
                
                // 验证 buffer policy
                // await boundedTimerByWrapping()
                
                // Back pressure
                // await backPressure()
                
                // Timer publisher 转换到 AsyncStream
                // try await timerByPublisher()
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    func syncFib() {
        for v in FibonacciSequence() {
            if v < 200 {
                print("Fib: \(v)")
            } else {
                break
            }
        }
    }
    
    func classAsyncFib() async throws {
        
        let asyncFib = ClassFibonacciSequence()
        for try await v in asyncFib {
            if v < 20 {
                print("Async Fib: \(v)")
            } else {
                break
            }
        }
        
        for try await v in asyncFib {
            print("New Fib: \(v)")
            break
        }
    }
    
    func transformAsyncFib() async throws {
        let seq = AsyncFibonacciSequence()
            .filter { $0.isMultiple(of: 2) }
            .prefix(5)
            .map { $0 * 2 }
        
        for try await v in seq {
            print(v)
        }
    }
    
    func debugFib() async throws {
        let seq = AsyncFibonacciSequence()
            .prefix(5)
            .print()
            .filter { $0.isMultiple(of: 2) }
            .map { $0 * 2 }
        for try await v in seq {
            print("Value: \(v)")
        }
    }
    
    var transformedFibonacciSequence: some AsyncSequence {
        AsyncFibonacciSequence()
            .filter { $0.isMultiple(of: 2) }
            .prefix(5)
            .map { $0 * 2 }
    }
    
    var timerStream: AsyncStream<Date> {
        timerStream(bufferingPolicy: .unbounded)
    }
    
    func timerStream(bufferingPolicy policy: AsyncStream<Date>.Continuation.BufferingPolicy) -> AsyncStream<Date> {
        AsyncStream(bufferingPolicy: policy) { continuation in
            let initial = Date()
            Task {
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
                    timer in
                    let now = Date()
                    let result = continuation.yield(Date())
                    print("Call yield: \(result)")
                    let diff = now.timeIntervalSince(initial)
                    if diff > 10 {
                        print("Call finish")
                        continuation.finish()
                        timer.invalidate()
                    }
                }
                continuation.onTermination = { state in
                    print("onTermination: \(state)")
                }
            }
        }
    }
    
    func timerByWrapping() async {
        Task {
            let timer = timerStream
            try await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
            for await v in timer {
                print(v)
            }
            
            print("Done")
        }
    }
    
    func boundedTimerByWrapping() async {
        Task {
            let timer = timerStream(bufferingPolicy: .bufferingNewest(0))
            try await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
            for await v in timer {
                print(v)
            }
            
            print("Done")
        }
    }
    
    func backPressure() async {
        Task {
            let timer = AsyncStream<Date> {
                try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
                return Date()
            } onCancel: { @Sendable in
                print("Cancelled.")
            }
            for await v in timer {
                print(v)
            }
            print("Done")
        }
        
    }
    
    func timerByPublisher() async throws {
        let stream = Timer.publish(every: 1, on: .main, in: .default)
            .autoconnect()
            .asAsyncStream
        for try await v in stream {
            print(v)
        }
    }
    
}

struct FibonacciSequence: Sequence {
    struct Iterator: IteratorProtocol {
        var state = (0, 1)
        
        mutating func next() -> Int? {
            let upcomingNumber = state.0
            state = (state.1, state.0 + state.1)
            return upcomingNumber
        }
    }
    
    func makeIterator() -> Iterator {
        .init()
    }
}

struct AsyncFibonacciSequence: AsyncSequence {
    typealias Element = Int
    struct AsyncIterator: AsyncIteratorProtocol {
        
        var currentIndex = 0
        
        mutating func next() async throws -> Int? {
            defer { currentIndex += 1 }
            return try await loadFibNumber(at: currentIndex)
        }
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        .init()
    }
}

class ClassFibonacciSequence: AsyncSequence {
    typealias Element = Int
    
    private var iterator: AsyncIterator?
    
    class AsyncIterator: AsyncIteratorProtocol {
        var currentIndex = 0
        func next() async throws -> Int? {
            defer { currentIndex += 1 }
            return try await loadFibNumber(at: currentIndex)
        }
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        if iterator == nil {
            iterator = .init()
        }
        return iterator!
    }
}

class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
}

struct BoxedAsyncFibonacciSequence: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = Int
    
    var currentIndex = Box(0)
    
    mutating func next() async throws -> Int? {
        defer { currentIndex.value += 1 }
        return try await loadFibNumber(at: currentIndex.value)
    }
    
    func makeAsyncIterator() -> Self {
        self
    }
}

func loadFibNumber(at index: Int) async throws -> Int {
    // Some API...
    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
    return fibNumber(at: index)
}

func fibNumber(at index: Int) -> Int {
    if index == 0 { return 0 }
    if index == 1 { return 1 }
    return fibNumber(at: index - 2) + fibNumber(at: index - 1)
}

extension AsyncSequence {
    func myContains(
        where predicate: (Self.Element) async throws -> Bool
    ) async rethrows -> Bool
    {
        for try await v in self {
            if try await predicate(v) {
                return true
            }
        }
        return false
    }
}

struct AsyncSideEffectSequence<Base: AsyncSequence>: AsyncSequence {
    
    struct AsyncIterator: AsyncIteratorProtocol {
        
        private var base: Base.AsyncIterator
        private let block: (Element) async -> ()
        
        init(_ base: Base.AsyncIterator, block: @escaping (Element) async -> ()) {
            self.base = base
            self.block = block
        }
        
        mutating func next() async throws -> Base.Element? {
            let value = try await base.next()
            if let value = value {
                await block(value)
            }
            return value
        }
    }
    
    typealias Element = Base.Element
    
    private let base: Base
    private let block: (Element) async -> ()
    
    init(_ base: Base, block: @escaping (Element) -> ()) {
        self.base = base
        self.block = block
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(base.makeAsyncIterator(), block: block)
    }
}

extension AsyncSequence {
    func print() -> AsyncSideEffectSequence<Self> {
        AsyncSideEffectSequence(self) { Swift.print("Got new value: \($0)") }
    }
}

extension Publisher {
    var asAsyncStream: AsyncThrowingStream<Output, Error> {
        AsyncThrowingStream(Output.self) { continuation in
            let cancellable = sink { completion in
                switch completion {
                case .finished:
                    continuation.finish()
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            } receiveValue: { output in
                continuation.yield(output)
            }
            
            continuation.onTermination = { @Sendable _ in cancellable.cancel() }
        }
    }
}



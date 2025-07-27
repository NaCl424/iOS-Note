//
//  ViewController.swift
//  Chapter09-Sendable
//
//  Created by Wang Wei on 2021/08/28.
//

import UIKit
import ModuleA

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        // let person = PersonClass(name: "onevcat")
        let person = PersonStruct(name: "onevcat")
        

        for i in 0 ..< 10000 {
            Task {
                let room = Room(roomName: "room \(i)")
                let p = await room.visit(person)
                print(p.message)
            }
        }
        
        bar(value: 1) {
            print(person)
        }
        
        let v = NSMutableString()
        bar(value: 1) {
            print(v)
        }
        
        let _ = AsyncStream<Int> { continuation in
            
            continuation.yield(12)
            
            continuation.onTermination = { @Sendable t in
                print(person.message)
            }
        }
        
        foo(value: person)
        foo(value: PersonModuleA(name: "a"))
        foo(value: PersonActorModuleA(name: "a"))
        
        let cube = CubeOwner(name: "", cube: .init(edge: 1))
        foo(value: cube)
        
        ModuleA.bar(value: 1) {
            print(person.message)
            print("Hello")
        }
    }
}

struct R {
    var hello: String
}

struct PersonStruct {
    let name: String
    var message: String = ""
        
    init(name: String) {
        self.name = name
    }
}

class PersonClass: Sendable {
    let name: String
    var message: String = ""
    
    init(name: String) {
        self.name = name
    }
}

actor Room: Sendable {
    let roomName: String
    
    init(roomName: String) {
        self.roomName = roomName
    }
}

extension Room {
    func visit(_ visitor: PersonStruct) -> PersonStruct {
        var result = visitor
        result.message = "Hello, \(visitor.name). From \(roomName)."
        return result
    }
}

extension Room {
    
    func visit(_ visitor: PersonClass) -> PersonClass {
        visitor.message = "Hello, \(visitor.name). From \(roomName)."
        return visitor
    }
}

func foo<T: Sendable>(value: T) {
    print(value)
}

class A {}

actor Sample: Sendable {
    var hello: Int
    let a = A()
    
    init(v: Int) {
        self.hello = v
    }
    
}

func bar(value: Int, @_unsafeSendable block: () -> Void) {
    block()
}

class MyError: Error {
    var a = A()
}

class MyClass: @unchecked Sendable {
    private var value: Int = 0
    private let lock = NSLock()
    func update(_ value: Int) {
        lock.lock()
        self.value = value
        lock.unlock()
    }
}

struct CubeOwner {
    let name: String
    let cube: Cube
}

extension Cube: @unchecked Sendable {}

//
//  ViewController.swift
//  Chapter08
//
//  Created by Wang Wei on 2021/08/18.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        Task { await Op().bar() }
        
    }
}

class Person: CustomStringConvertible {
    var name: String
    var age: Int
    
    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
    
    var description: String {
        "Name: \(name), age: \(age)"
    }
}

class Op {
    func foo() {
        let room = Room()
        print(room)
        // room.visit()
    }
    
    func bar() async {
        let room = Room()
        let visitCount = await room.visit()
        print(visitCount)
        print(await room.visitorCount)
        print(await room.popularAsync)
        print(room)
        
        await room.changePersonName()
        room.unsafeChangePersonName()
    }
    
    func baz() async {
        let room = RoomClass()
        print(room.popularAsync)
        
        let anotherRoom: any PopularAsync = RoomClass()
        print(await anotherRoom.popularAsync)
    }
    
    func fur<T: PopularAsync>(value: T) async {
        print(await value.popularAsync)
    }
}


actor Room {
    let roomNumber = "101"
    var visitorCount: Int = 0
    
    private let person: Person
    
    init() {
        person = Person(name: "Lee", age: 18)
    }
    
    func visit() -> Int {
        visitorCount += 1
        return visitorCount
    }
    
    func reportPopular() {
        if internalPopular {
            print("Popular")
        }
    }
    
    func tryJoin() async {
        let room = Room()
        await reportRoom(room: room)
        reportRoom(room: self)
        await add(room)
        _ = await addCount(room1: self, room2: room)
        _ = await addCount(room1: self, room2: self)
    }
    
    func add(_ another: Room) async {
        _ = await addCount(room1: self, room2: another)
    }
    
    func addAsync(_ another: isolated Room) async {
        print(await self.visitorCount)
        _ = await addCount(room1: self, room2: another)
    }
    
    func baz1(_ another: Room) async {
        print(self.visitorCount)
        print(await another.visitorCount)
        // ...
    }
    
    func baz2(_ another: isolated Room) async {
        print(await visitorCount)
        print(another.visitorCount)
        // ...
    }
}

extension Room: Popular {
    nonisolated var popular: Bool {
        roomNumber.count > 3
    }
}

extension Room: PopularActor {
    var popularActor: Bool {
        visitorCount > 10
    }
}

extension Room: PopularAsync {
    private var internalPopular: Bool {
        visitorCount > 10
    }
    
    var popularAsync: Bool {
        get async {
            internalPopular
        }
    }
}

protocol Popular {
    var popular: Bool { get }
}

protocol PopularActor: Actor {
    var popularActor: Bool { get }
}

protocol PopularAsync {
    var popularAsync: Bool { get async }
}

extension Room: CustomStringConvertible {
    nonisolated var description: String {
        "Room \(roomNumber)"
    }
}

extension Room {
    func changePersonName() {
        person.name = "Bruce"
        print("Person: \(person)")
    }
    
    nonisolated func unsafeChangePersonName() {
        person.name = "Bruce"
        print("Person: \(person)")
    }
}

class RoomClass: PopularAsync {
    var popularAsync: Bool { return true }
}

func addCount(room1: Room, room2: isolated Room) async -> Int {
    let count = await room1.visitorCount + room2.visitorCount
    print("room1: \(await room1.visitorCount)")
    print("room2: \(room2.visitorCount)")
    print("Count: \(count)")
    return count
}

func reportRoom(room: isolated Room) {
    print("Room: \(room.visitorCount)")
}



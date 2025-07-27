//
//  PersonModuleA.swift
//  PersonModuleA
//
//  Created by Wang Wei on 2021/08/30.
//

import UIKit

@frozen
public struct PersonModuleA {
    let name: String
    var message: String = ""
    
    public init(name: String) {
        self.name = name
    }
}

public class A {}

public actor PersonActorModuleA {
    let name: String
    var message: String = ""
    
    public init(name: String) {
        self.name = name
    }
}

public struct Future<T: Sendable>: Sendable {
    public init() {}
}

public func bar<T: Sendable>(value: T, block: @Sendable () -> Void) {
    
}

public class Cube {
    public let edge: CGFloat
    private var a = A()
    
    public init(edge: CGFloat) {
        self.edge = edge
    }
}


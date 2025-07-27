//
//  Sample.swift
//  Sample
//
//  Created by Wang Wei on 2021/08/19.
//

@available(macOS 12.0, *)
actor MyActor {
    var count: Int = 0
    
    func case1() async {
        await method(value: 0, actor: self, another: self)
    }
    
    func case2() async {
        let another = MyActor()
        await method(value: 0, actor: self, another: another)
    }
    
    func case3() async {
        let another = MyActor()
        await method(value: 0, actor: another, another: self)
    }
    
    func case4() async {
        let one = MyActor()
        let another = MyActor()
        await method(value: 0, actor: one, another: another)
    }
}

@available(macOS 12.0, *)
func case5() async {
    let one = MyActor()
    let another = MyActor()
    await method(value: 0, actor: one, another: another)
}

@available(macOS 12.0, *)
func method(value: Int, actor: isolated MyActor, another: MyActor) async {
    print(actor.count)
    print(await another.count)
}

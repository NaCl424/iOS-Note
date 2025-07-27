//
//  ViewController.swift
//  Chapter06
//
//  Created by Wang Wei on 2021/07/28.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        Task {
            // await TaskGroupSample().start()
            // await TaskGroupDataErrorSample().start()
            // await TaskGroupEscapingSample().start()
            // await TaskGroupDeferSample().start()
            // await AsyncLetSample().start()
            // await AsyncLetWithoutAwaitSample().start()
            // await TaskGroupCombination().start()
            // await AsyncLetCombination().start()
            // await TopLevelTask().start()
            print("Task done")
        }
    }
}

struct TaskGroupSample {
    
    func start() async {
        print("Start")
        let v: Int = await withTaskGroup(of: Int.self) { group in
            var value = 0
            for i in 0 ..< 3 {
                group.addTask {
                    await work(i)
                }
            }
            print("Task added")
            for await result in group {
                print("Get result: \(result)")
                value += result
            }
            print("Task ended")
            return value
        }
        
        print("End. Result: \(v)")
    }
}

struct TaskGroupEscapingSample {
    func start() async {
        print("Start")
        var g: TaskGroup<Int>? = nil
        await withTaskGroup(of: Int.self) { group in
            g = group
            for i in 0 ..< 3 {
                group.addTask {
                    await work(i)
                }
            }
            print("Task added")
            for await result in group {
                print("Get result: \(result)")
                break
            }
            print("Task ended")
        }
        g?.addTask {
            await work(1)
        }
        print("End")
    }
}

class TaskGroupDataErrorSample {
    var value: Int = 0
    func start() async {
        print("Start")
        await withTaskGroup(of: Int.self) { group in
            for i in 0 ..< 1000 {
                group.addTask {
                    let v = self.value
                    let result = await work(i)
                    self.value = v + result
                    return result
                }
            }
            print("Task added")
            for await result in group {
                print("Get result: \(result)")
            }
            print("Task ended")
        }
        print("Value: \(value)")
    }
}


struct TaskGroupDeferSample {
    
    func start() async {
        print("Start")
        await withTaskGroup(of: Int.self) { group in
            defer {
                print("Defer..")
            }
            for i in 0 ..< 3 {
                group.addTask {
                    await work(i)
                }
            }
            print("Task added")
            print("Task ended")
            await group.waitForAll()
        }
        
        print("End")
    }
}

struct AsyncLetSample {
    
    func start() async {
        print("Start")
        async let v0 = work(0)
        async let v1 = work(1)
        async let v2 = work(2)
        print("Task added")
        
        let result = await v0 + v1 + v2
        
        print("Task ended")
        print("End. Result: \(result)")
    }
}

struct AsyncLetWithoutAwaitSample {
    
    func start() async {
        print("Start")
        async let v0 = work(0)
        async let v1 = work(1)
        async let v2 = work(2)
        print("Task added")

        print("Task ended")
        print("End.")
    }
}

struct TaskGroupCombination {
    func start() async {
        await withTaskGroup(of: Int.self) { group in
            group.addTask {
                await withTaskGroup(of: Int.self) { innerGroup in
                    innerGroup.addTask {
                        await work(0)
                    }
                    innerGroup.addTask {
                        await work(2)
                    }
                    
                    return await innerGroup.reduce(0) { result, value in
                        result + value
                    }
                }
            }
            group.addTask {
                await work(1)
            }
        }
        print("End")
    }
}

struct AsyncLetCombination {
    func start() async {
        
        async let v02: Int = {
            await work(0) + work(2)
        }()
        
        async let v1 = work(1)
        
        _ = await v02 + v1
        print("End")
    }
}

struct TopLevelTask {
    func start() async {
        let t1 = Task {
            await work(1)
        }
        
        let t2 = Task.detached {
            await work(2)
        }
        
        let v1 = await t1.value
        let v2 = await t2.value
        
        print("Result: \(v1 + v2)")
    }
}

func work(_ value: Int) async -> Int {
    print("Start work \(value)")
    // print("Task \(value) cancelled: \(Task.isCancelled)")
    try? await Task.sleep(nanoseconds: UInt64(value) * NSEC_PER_SEC)
    print("Work \(value) done")
    return value
}

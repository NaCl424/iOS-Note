//
//  ViewController.swift
//  Chapter09
//
//  Created by Wang Wei on 2021/08/20.
//

import UIKit

class ViewController: UIViewController {

    var value: String? = "Hello"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let url = URL(string: "https://example.com")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            print(Thread.current.isMainThread) // false
            DispatchQueue.main.async {
                print(Thread.current.isMainThread) // true
                self.updateUI(data)
            }
        }
        task.resume()
        
        Task {
            C1().method()
            C1().anotherMethod()
            C2().method()
            S1().method()
            print(C2().value ?? 0)
        }
                
        Task.detached {
            await C1().method()
            
            let c1 = await C1()
            c1.anotherMethod()
            
            await C2().method()
            C2().anotherMethod()
            print(await C2().value ?? 0)
            
            await S1().method()
            print("Miao")
        }
        
        Task {
            let (data, _) = try await URLSession.shared.data(from: url)
            self.updateUI(data)
        }
        
        Task.detached {
            let (data, _) = try await URLSession.shared.data(from: url)
            await self.updateUI(data)
        }
        
        let room = Room()
        Task {
            _ = await room.visit()
            let r = await room.study()
            print(String(describing: r))
        }
        
        Task {
            for _ in 0 ..< 100 {
                _ = await room.visit()
            }
        }
        
        M().foo()
    }
    
    private func updateUI(_ data: Data?) {
        
    }
    
    @MainActor func explicitUIMethod() {
        
    }
}

class Sample {
    func foo() {
        Task { await C1().method() }
        Task { @MainActor in C1().method() }
        Task { @MainActor in globalValue = "Hello" }
        DispatchQueue.main.async {
            C1().method()
            globalValue = "World"
        }
    }
    
    func bar() async {
        await C1().method()
        await MainActor.run {
            C2().method()
            C2().anotherMethod()
        }
        C2().anotherMethod()
    }
}

class ViewControllerSample {
    func foo() {
        let button = UIButton()
        button.setTitle("Click", for: .normal)
        ViewController().view.addSubview(button)
        
        Task {
            await ViewController().explicitUIMethod()
        }
        
    }
    
    func bar() async {
        let button = await UIButton()
        await button.setTitle("Click", for: .normal)
        await ViewController().view.addSubview(button)
    }
}

@MainActor class C1 {
    func method() {}
    nonisolated func anotherMethod() {}
}

class C2 {
    @MainActor var value: Int?
    @MainActor func method() {}
    nonisolated func anotherMethod() {}
}

@MainActor var globalValue: String = ""

@MainActor struct S1 {
    func method() {}
}

extension DispatchQueue {
    static func mainAsyncOrExecute(_ work: @escaping () -> Void) {
        if Thread.current.isMainThread {
            work()
        } else {
            main.async { work() }
        }
    }
}


@globalActor actor MyActor {
    static let shared = MyActor()
    var value: Int = 0
}

@MyActor var foo = "some value"

@MyActor func bar(actor: MyActor) async {
    print(await actor.value)
    print(await MyActor.shared.value)
}

actor Room {
    var visitorCount: Int = 0
    var isPopular: Bool { visitorCount > 10 }
    
    func visit() -> Int {
        visitorCount += 1
        return visitorCount
    }
    
    func study() async -> Report? {
        if !isPopular {
            let reason = await analyze(room: self)
            return Report(reason: reason, visitorCount: visitorCount)
        }
        return nil
    }
}

struct Report {
    let reason: String
    let visitorCount: Int
}

func analyze(room: Room) async -> String {
    try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
    return "Some Reason"
}

class C {
    var foo: String = ""
}

actor A {
    func foo(c: C, v: String) async {
        try? await Task.sleep(nanoseconds: 100)
        c.foo = v
    }
}

class M {
    func foo() {
        let c = C()
        
        for i in 0 ..< 100 {
            Task.detached {
                await A().foo(c: c, v: "value \(i)")
            }
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 10000)
            print(c.foo)
        }
        Task.detached {
            let counter = Counter()
            Task {
              counter.increment() // SE-0302 error: cannot use let 'counter' with a non-sendable type 'Counter' from concurrently-executed code
            }

        }
        
    }
}
class Counter {
  var value = 0
  
  func increment() {
      
  }
}


actor SomeActor {
  // async functions are usable *within* the actor, so this
  // is ok to declare.
  func doThing(string: Counter) async {
      
  }
}

// ... but they cannot be called by other code not protected
// by the actor's mailbox:
func f(a: SomeActor, myString: Counter) async {
  // error: 'NSMutableString' may not be passed across actors;
  //        it does not conform to 'Sendable'
  await a.doThing(string: myString)
}

struct MyCorrectPair {
  var a, b: Int
}



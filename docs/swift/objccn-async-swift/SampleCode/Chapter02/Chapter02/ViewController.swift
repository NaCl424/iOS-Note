//
//  ViewController.swift
//  Chapter02
//
//  Created by Wang Wei on 2021/06/28.
//

import UIKit

actor Holder {
    var results: [String] = []
    func setResults(_ results: [String]) {
        self.results = results
    }
    
    func append(_ value: String) {
        results.append(value)
    }
}

@globalActor
actor MyActor {
    static let shared = MyActor()
}

class ViewController: UIViewController {

    var holder = Holder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        for i in 0 ..< 10000 {
            someSyncMethod(index: i)
        }
    }
    
    func someSyncMethod(index: Int) {
        Task {
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.loadResultRemotely()
                }
                group.addTask(priority:. low) {
                    try await self.processFromScratch()
                }
            }
            print("Done Task: \(index)")
        }
    }
    
    func loadResultRemotely() async throws {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC + NSEC_PER_SEC / 80)
        await holder.setResults(["data1^sig", "data2^sig", "data3^sig"])
    }

    func processFromScratch() async throws {
        async let loadStrings = loadFromDatabase()
        async let loadSignature = loadSignature()
        
        let strings = try await loadStrings
        if let signature = try await loadSignature {
            await holder.setResults([])
            for data in strings {
                await holder.append(data.appending(signature))
            }
        } else {
            throw NoSignatureError()
        }
    }

    
    func loadSignature() async throws -> String? {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        return "^sig"
    }
    
    func loadFromDatabase() async throws -> [String] {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        return ["data1", "data2", "data3"]
    }
}

struct NoSignatureError: Error {}

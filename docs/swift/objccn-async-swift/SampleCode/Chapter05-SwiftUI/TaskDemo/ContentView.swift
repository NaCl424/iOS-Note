//
//  ContentView.swift
//  TaskDemo
//
//  Created by Wang Wei on 2021/07/28.
//

import SwiftUI

struct ContentView: View {
    
    @State private var result = ""
    @State private var loading = true
    
    var body: some View {
        
        // Add/Remove view with `task`.
        if loading {
            // view1
        }
        
        
        // Add/Remove view with `onAppear`.
        if loading {
            // view2
        }
        
        // Use opacity to control visual effect.
        view1.opacity(loading ? 1.0 : 0.0)
        
        Text(result)
            .onAppear { loading = false }
    }
    
    var view1: some View {
        ProgressView()
            .task {
                let value = try? await load()
                result = value ?? "<nil>"
                loading = false
            }
    }
    
    var view2: some View {
        ProgressView()
            .onAppear {
                Task {
                    let value = try? await load()
                    result = value ?? "<nil>"
                    loading = false
                }
            }
    }
    
    func load() async throws -> String {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        return "Hello World"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

//
//  ContentView.swift
//  DataMap
//
//  Created by ÖMER FARUK ATAK on 28.12.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GraphViewModel()
    
    var body: some View {
        MainAppLayout()
            .environmentObject(viewModel)
    }
}

#Preview {
    ContentView()
}

// 📁 File: Views/MapExplorerView.swift
// 🎯 LEGACY MAP VIEW - NOW REDIRECTS TO GRAPH VIEW

import SwiftUI

struct MapExplorerView: View {
    @EnvironmentObject private var viewModel: GraphViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Map View Deprecated")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("This app now uses graph-based visualization instead of geographic mapping. Files and folders are displayed as connected nodes in a force-directed graph.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                NavigationLink("Open Graph View", destination: GraphView())
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .navigationTitle("Map Explorer")
        }
    }
}

// MARK: - Preview
struct MapExplorerView_Previews: PreviewProvider {
    static var previews: some View {
        MapExplorerView()
            .environmentObject(GraphViewModel())
    }
}
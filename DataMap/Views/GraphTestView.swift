// 📁 File: Views/GraphTestView.swift
// 🎯 TEST VIEW FOR GRAPH-BASED ARCHITECTURE

import SwiftUI

struct GraphTestView: View {
    @StateObject private var viewModel = GraphViewModel()
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Text("DataMap Graph Explorer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Force-directed file system visualization")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Status
                if viewModel.isLoading {
                    VStack {
                        ProgressView("Scanning files...")
                        Text("Progress: \(Int(viewModel.scanProgress * 100))%")
                            .font(.caption)
                    }
                    .padding()
                } else if viewModel.nodes.isEmpty {
                    VStack {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("No files loaded")
                            .font(.headline)
                        
                        Text("Load a directory to see the graph visualization")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    // Graph statistics
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Nodes:")
                            Spacer()
                            Text("\(viewModel.nodes.count)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Edges:")
                            Spacer()
                            Text("\(viewModel.edges.count)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Layout Progress:")
                            Spacer()
                            Text("\(Int(viewModel.layoutProgress * 100))%")
                                .fontWeight(.semibold)
                        }
                        
                        if viewModel.isLayoutRunning {
                            ProgressView(value: viewModel.layoutProgress)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    // Graph View
                    GraphView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Load Sample Data") {
                        loadSampleData()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Load Documents Folder") {
                        loadDocumentsFolder()
                    }
                    .buttonStyle(.bordered)
                    
                    if !viewModel.nodes.isEmpty {
                        Button("Reset Layout") {
                            viewModel.resetLayout()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Graph Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        .environmentObject(viewModel)
    }
    
    private func loadSampleData() {
        let sampleNodes = FileNode.previewHierarchy
        viewModel.loadHierarchy(sampleNodes)
    }
    
    private func loadDocumentsFolder() {
        isLoading = true
        
        Task {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory()
            
            await viewModel.loadDirectory(documentsPath)
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

struct GraphTestView_Previews: PreviewProvider {
    static var previews: some View {
        GraphTestView()
    }
}
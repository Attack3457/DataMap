// 📁 File: Views/UtilityViews.swift
// 🎯 UTILITY VIEWS AND COMPONENTS

import SwiftUI
import CoreLocation

// MARK: - Content Column View
struct ContentColumnView: View {
    let selectedTab: AppTab
    let selectedProject: Project?
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        switch selectedTab {
        case .map:
            GraphView()
                .navigationDestination(for: FileNode.self) { node in
                    NodeDetailView(node: node)
                }
        case .browser:
            FileBrowserView()
                .navigationDestination(for: FileNode.self) { node in
                    NodeDetailView(node: node)
                }
        case .projects:
            ProjectsView(selectedProject: .constant(selectedProject))
        case .statistics:
            StatisticsView()
        case .settings:
            MapSettingsView()
        }
    }
}

// MARK: - Detail Column View
struct DetailColumnView: View {
    let selectedTab: AppTab
    let selectedProject: Project?
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        Group {
            if let project = selectedProject {
                ProjectDetailView(project: project)
            } else {
                Text("Select a project to view details")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Project Detail View
struct ProjectDetailView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(project.name)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(project.projectDescription)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Created", systemImage: "calendar")
                Text(project.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Files", systemImage: "doc")
                Text("\(project.nodes.count) items")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Node Detail View
struct NodeDetailView: View {
    let node: FileNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: node.systemImageName)
                    .font(.title2)
                    .foregroundColor(Color(hex: node.colorHex))
                
                VStack(alignment: .leading) {
                    Text(node.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(node.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                UtilityDetailRow(label: "Type", value: node.isDirectory ? "Directory" : "File")
                UtilityDetailRow(label: "Size", value: node.formattedSize)
                UtilityDetailRow(label: "Modified", value: node.formattedDate)
                
                if node.isDirectory {
                    UtilityDetailRow(label: "Items", value: "\(node.children.count)")
                }
                
                if !node.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 4) {
                            ForEach(node.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle(node.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Utility Detail Row (renamed to avoid conflicts)
struct UtilityDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Loading States
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action, let actionTitle = actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let error: Error
    let retry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let retry = retry {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Global Loading Overlay
struct GlobalLoadingOverlay: View {
    @EnvironmentObject private var viewModel: GraphViewModel
    
    var body: some View {
        if viewModel.isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Loading...")
                        .font(.headline)
                    
                    if viewModel.scanProgress > 0 {
                        ProgressView(value: viewModel.scanProgress)
                            .frame(width: 200)
                        
                        Text("\(Int(viewModel.scanProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
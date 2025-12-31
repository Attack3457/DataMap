// 📁 File: Views/FileBrowserView.swift
// 🎯 COMPREHENSIVE FILE BROWSER WITH MULTIPLE VIEW MODES

import SwiftUI
import CoreLocation
import SwiftData

// MARK: - File Browser View
struct FileBrowserView: View {
    @EnvironmentObject private var viewModel: GraphViewModel
    @State private var sortOrder = [KeyPathComparator(\FileNode.name)]
    @State private var selection = Set<FileNode.ID>()
    @State private var isShowingFilter = false
    @State private var viewMode: ViewMode = .list
    
    enum ViewMode {
        case list, grid, hierarchy
    }
    
    var body: some View {
        Group {
            switch viewMode {
            case .list:
                fileListView
            case .grid:
                gridView
            case .hierarchy:
                hierarchyView
            }
        }
        .navigationTitle("File Browser")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ToolbarView(
                    selection: $selection,
                    viewMode: $viewMode,
                    onFilterTap: { isShowingFilter = true }
                )
            }
        }
        .sheet(isPresented: $isShowingFilter) {
            FilterView()
        }
        .searchable(text: $viewModel.searchText, prompt: "Search files...")
        .onChange(of: viewModel.searchText) { oldValue, newValue in
            // Filter updates are handled automatically by the ViewModel
        }
    }
    
    private var fileListView: some View {
        let nodes = viewModel.filteredNodes
        
        return Table(nodes, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { node in
                HStack {
                    Image(systemName: node.systemImageName)
                        .foregroundColor(Color(hex: node.colorHex))
                    Text(node.name)
                    Spacer()
                    if node.isDirectory {
                        Text("\(node.children.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            TableColumn("Size", value: \.size) { node in
                Text(node.formattedSize)
                    .foregroundColor(.secondary)
            }
            
            TableColumn("Modified", value: \.modifiedAt) { node in
                Text(node.formattedDate)
                    .foregroundColor(.secondary)
            }
            
            TableColumn("Position") { node in
                Text(String(format: "%.2f, %.2f", 
                           node.graphX,
                           node.graphY))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: sortOrder) { oldOrder, newOrder in
            // Apply sorting to filtered nodes
            // Note: This would need to be implemented in the ViewModel
        }
    }
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 12)
            ], spacing: 12) {
                ForEach(viewModel.filteredNodes.prefix(100)) { node in
                    FileGridItem(node: node)
                }
            }
            .padding()
        }
    }
    
    private var hierarchyView: some View {
        List(viewModel.nodes.filter { $0.parent == nil }) { node in
            DisclosureGroup {
                ForEach(node.children) { child in
                    HierarchyRow(node: child, depth: 1)
                }
            } label: {
                FileRow(node: node)
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Supporting Views
struct FileRow: View {
    let node: FileNode
    let showIcon: Bool = true
    
    var body: some View {
        HStack {
            if showIcon {
                Image(systemName: node.systemImageName)
                    .foregroundColor(Color(hex: node.colorHex))
                    .frame(width: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .lineLimit(1)
                Text(node.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if node.isDirectory {
                Text("\(node.children.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HierarchyRow: View {
    let node: FileNode
    let depth: Int
    
    var body: some View {
        Group {
            if node.children.isEmpty {
                FileRow(node: node)
            } else {
                DisclosureGroup {
                    ForEach(node.children) { child in
                        HierarchyRow(node: child, depth: depth + 1)
                    }
                } label: {
                    FileRow(node: node)
                }
            }
        }
        .padding(.leading, CGFloat(depth * 20))
    }
}

struct FileGridItem: View {
    let node: FileNode
    
    var body: some View {
        VStack {
            Image(systemName: node.systemImageName)
                .font(.system(size: 32))
                .foregroundColor(Color(hex: node.colorHex))
                .frame(width: 60, height: 60)
                .background(Color(hex: node.colorHex).opacity(0.1))
                .cornerRadius(12)
            
            Text(node.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            
            if node.isDirectory {
                Text("\(node.children.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

struct ToolbarView: View {
    @EnvironmentObject private var viewModel: GraphViewModel
    @Binding var selection: Set<FileNode.ID>
    @Binding var viewMode: FileBrowserView.ViewMode
    let onFilterTap: () -> Void
    
    var body: some View {
        Group {
            // View mode selector
            Picker("View", selection: $viewMode) {
                Image(systemName: "list.bullet").tag(FileBrowserView.ViewMode.list)
                Image(systemName: "square.grid.2x2").tag(FileBrowserView.ViewMode.grid)
                Image(systemName: "flowchart").tag(FileBrowserView.ViewMode.hierarchy)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            
            // Scan button
            Button("Scan", systemImage: "magnifyingglass") {
                startScan()
            }
            
            // Filter button
            Button("Filter", systemImage: "line.3.horizontal.decrease.circle") {
                onFilterTap()
            }
            
            // Selection actions
            if !selection.isEmpty {
                Menu {
                    Button("Tag Selection", systemImage: "tag") {
                        tagSelected()
                    }
                    Button("Export Selection", systemImage: "square.and.arrow.up") {
                        exportSelected()
                    }
                    Divider()
                    Button("Delete Selection", systemImage: "trash", role: .destructive) {
                        deleteSelected()
                    }
                } label: {
                    Label("Selected", systemImage: "checkmark.circle")
                        .labelStyle(.iconOnly)
                }
            }
        }
    }
    
    private func startScan() {
        Task {
            if let documentsURL = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first {
                await viewModel.scanDirectory(documentsURL)
            }
        }
    }
    
    private func tagSelected() {
        // Implement tag functionality
    }
    
    private func exportSelected() {
        // Implement export functionality
    }
    
    private func deleteSelected() {
        // Implement delete functionality with confirmation
    }
}
// 📁 File: Views/SidebarView.swift
// 🎯 SIDEBAR NAVIGATION FOR IPAD/MAC LAYOUT

import SwiftUI
import SwiftData

// MARK: - Sidebar View
struct SidebarView: View {
    @EnvironmentObject private var viewModel: GraphViewModel
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedProject: Project?
    @Binding var selectedTab: AppTab
    @Binding var searchText: String
    @FocusState var isSearchFocused: Bool
    
    let onCreateProject: () -> Void
    let onImport: () -> Void
    
    @Query private var projects: [Project]
    @State private var isShowingProjectMenu = false
    
    var body: some View {
        List {
            navigationSection
            projectsSection
            recentScansSection
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Search projects...")
        .focused($isSearchFocused)
    }
    
    // MARK: - View Components
    
    private var navigationSection: some View {
        Section("Navigation") {
            ForEach(AppTab.allCases) { tab in
                if tab != .settings {
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .badge(tabBadge(for: tab) ?? 0)
                }
            }
        }
    }
    
    private var projectsSection: some View {
        Section("Projects") {
            ForEach(projects) { project in
                ProjectRow(
                    project: project,
                    isSelected: selectedProject?.id == project.id
                )
                .onTapGesture {
                    selectedProject = project
                    selectedTab = .projects
                }
            }
            
            Button(action: onCreateProject) {
                Label("New Project", systemImage: "plus.circle")
            }
            .foregroundColor(.blue)
        }
    }
    
    private var recentScansSection: some View {
        Section("Recent Scans") {
            if viewModel.nodes.isEmpty {
                Text("No scans yet")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(viewModel.nodes.prefix(5)) { node in
                    RecentScanRow(node: node)
                }
            }
        }
    }
    
    private var allTags: [String] {
        viewModel.nodes.flatMap { $0.tags }.uniqued()
    }
    
    private func tabBadge(for tab: AppTab) -> Int? {
        switch tab {
        case .browser:
            return viewModel.nodes.count
        case .projects:
            return projects.count
        default:
            return nil
        }
    }
    
    private func startQuickScan() {
        Task {
            if let documentsURL = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first {
                await viewModel.scanDirectory(documentsURL)
            }
        }
    }
    
    private func startFullScan() {
        Task {
            // Use iOS-compatible way to get user directory
            let homeURL = FileManager.default.urls(for: .userDirectory, in: .userDomainMask).first ?? 
                         FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            await viewModel.scanDirectory(homeURL)
        }
    }
    
    private func refreshData() {
        // Refresh projects and data
        Task {
            await viewModel.loadExistingData()
        }
    }
}

// MARK: - Supporting Views
struct ProjectRow: View {
    let project: Project
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "globe.desk.fill")
                .foregroundColor(isSelected ? .blue : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(project.totalNodes) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct RecentScanRow: View {
    let node: FileNode
    
    var body: some View {
        HStack {
            Image(systemName: node.systemImageName)
                .foregroundColor(Color(hex: node.colorHex))
                .frame(width: 20)
            
            Text(node.name)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            Text(node.formattedDate)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct ProjectContextMenu: View {
    let project: Project
    
    var body: some View {
        Button("Open", systemImage: "folder") {
            // Open project
        }
        Button("Export", systemImage: "square.and.arrow.up") {
            // Export project
        }
        Button("Duplicate", systemImage: "doc.on.doc") {
            // Duplicate project
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            // Delete project with confirmation
        }
    }
}

struct SidebarFooter: View {
    let nodeCount: Int
    let onSettingsTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(nodeCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if nodeCount > 0 {
                        Text("\(formatBytes(totalSize)) total")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onSettingsTap) {
                    Image(systemName: "gear")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.background)
        }
    }
    
    private var totalSize: Int64 {
        // Calculate total size (would need access to viewModel)
        0
    }
}

// MARK: - Extensions
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}
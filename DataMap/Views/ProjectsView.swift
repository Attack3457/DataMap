// 📁 File: Views/ProjectsView.swift
// 🎯 PROJECT MANAGEMENT AND OVERVIEW

import SwiftUI
import SwiftData

// MARK: - Projects View
struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @Binding var selectedProject: Project?
    
    @State private var isShowingDeleteAlert = false
    @State private var projectToDelete: Project?
    
    var body: some View {
        List(selection: $selectedProject) {
            if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "globe.desk",
                    description: Text("Create your first project to start mapping")
                )
            } else {
                ForEach(projects) { project in
                    ProjectCard(project: project)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                projectToDelete = project
                                isShowingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                duplicateProject(project)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            Button("Open", systemImage: "folder") {
                                selectedProject = project
                            }
                            Button("Export", systemImage: "square.and.arrow.up") {
                                exportProject(project)
                            }
                            Divider()
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                projectToDelete = project
                                isShowingDeleteAlert = true
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Project", systemImage: "plus") {
                    createNewProject()
                }
            }
        }
        .alert("Delete Project", isPresented: $isShowingDeleteAlert, presenting: projectToDelete) { project in
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteProject(project)
            }
        } message: { project in
            Text("Are you sure you want to delete '\(project.name)'? This action cannot be undone.")
        }
    }
    
    private func createNewProject() {
        let project = Project(
            name: "New World \(projects.count + 1)",
            rootPath: FileManager.default.urls(for: .documentDirectory,
                                             in: .userDomainMask).first!.path
        )
        modelContext.insert(project)
        selectedProject = project
    }
    
    private func duplicateProject(_ project: Project) {
        let newProject = Project(
            name: "\(project.name) Copy",
            rootPath: project.rootPath
        )
        
        // Copy nodes
        for node in project.nodes {
            let newNode = FileNode(
                name: node.name,
                path: node.path,
                nodeType: node.nodeType,
                size: node.size,
                graphPosition: SIMD2<Double>(node.graphX, node.graphY),
                createdAt: node.createdAt,
                modifiedAt: node.modifiedAt
            )
            newProject.addNode(newNode)
        }
        
        modelContext.insert(newProject)
        selectedProject = newProject
    }
    
    private func exportProject(_ project: Project) {
        // Implement export functionality
    }
    
    private func deleteProject(_ project: Project) {
        modelContext.delete(project)
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
        projectToDelete = nil
    }
}

// MARK: - Project Card
struct ProjectCard: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe.desk.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.headline)
                    Text("Created \(project.createdAt, format: .dateTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(project.totalNodes)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            if !project.nodes.isEmpty {
                ProgressView(value: Double(project.nodes.count), 
                           total: Double(max(project.totalNodes, 1)))
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                HStack {
                    Label("\(project.nodes.count) items", systemImage: "doc")
                        .font(.caption)
                    
                    Spacer()
                    
                    Label("\(formatBytes(project.totalSize))", systemImage: "externaldrive")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            } else {
                Text("No files scanned yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Utility Functions
private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}
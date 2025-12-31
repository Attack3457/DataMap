// 📁 File: Views/NewProjectView.swift
// 🎯 NEW PROJECT CREATION INTERFACE

import SwiftUI
import SwiftData

// MARK: - New Project View
struct NewProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName = ""
    @State private var selectedPath = ""
    @State private var isShowingFilePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $projectName)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Scan Location") {
                    HStack {
                        Text("Path:")
                        Spacer()
                        Text(selectedPath.isEmpty ? "Not selected" : selectedPath)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Button("Choose Directory") {
                        isShowingFilePicker = true
                    }
                    
                    // Quick options
                    Button("Use Documents") {
                        selectedPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
                    }
                    
                    Button("Use Home Directory") {
                        selectedPath = FileManager.default.urls(for: .userDirectory, in: .userDomainMask).first?.path ?? ""
                    }
                }
                
                Section("Options") {
                    // Add scan options here if needed
                    Text("Default scan settings will be used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(projectName.isEmpty || selectedPath.isEmpty)
                }
            }
        }
    }
    
    private func createProject() {
        let project = Project(
            name: projectName,
            rootPath: selectedPath
        )
        
        modelContext.insert(project)
        dismiss()
    }
}

// MARK: - Import View
struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Import Data")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Import previously exported project data or scan results")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    Button("Import from File") {
                        // Implement file import
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Import from iCloud") {
                        // Implement iCloud import
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Export View
struct ExportView: View {
    let project: Project?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Export Data")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let project = project {
                    Text("Export '\(project.name)' project data")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Export all project data and settings")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    Button("Export as JSON") {
                        // Implement JSON export
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Export to Files") {
                        // Implement Files app export
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button("Share") {
                        // Implement sharing
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
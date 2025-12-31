// 📁 File: Views/FilterView.swift
// 🎯 ADVANCED FILTERING INTERFACE

import SwiftUI

// MARK: - Filter View
struct FilterView: View {
    @EnvironmentObject private var viewModel: GraphViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Type") {
                    Toggle("Show Only Directories", isOn: $viewModel.showOnlyDirectories)
                    Toggle("Show Only Bookmarked", isOn: $viewModel.showOnlyBookmarked)
                }
                
                Section("Search") {
                    TextField("Search files and folders", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                if !viewModel.allTags.isEmpty {
                    Section("Tags") {
                        VStack(alignment: .leading) {
                            Text("Filter by Tags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                ForEach(viewModel.allTags, id: \.self) { tag in
                                    Button(action: {
                                        viewModel.toggleTagFilter(tag)
                                    }) {
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                viewModel.selectedTags.contains(tag) ? 
                                                Color.blue : Color.gray.opacity(0.2)
                                            )
                                            .foregroundColor(
                                                viewModel.selectedTags.contains(tag) ? 
                                                .white : .primary
                                            )
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Total Nodes:")
                        Spacer()
                        Text("\(viewModel.nodes.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Filtered Nodes:")
                        Spacer()
                        Text("\(viewModel.filteredNodes.count)")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Selected Tags:")
                        Spacer()
                        Text("\(viewModel.selectedTags.count)")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") {
                        clearFilters()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func clearFilters() {
        viewModel.showOnlyDirectories = false
        viewModel.showOnlyBookmarked = false
        viewModel.selectedTags.removeAll()
        viewModel.searchText = ""
    }
}
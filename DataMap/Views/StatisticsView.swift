// 📁 File: Views/StatisticsView.swift
// 🎯 COMPREHENSIVE STATISTICS AND ANALYTICS

import SwiftUI
import Charts

// MARK: - Statistics View
struct StatisticsView: View {
    @EnvironmentObject private var viewModel: GraphViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(
                        title: "Total Files",
                        value: "\(viewModel.calculateStatistics().totalFiles)",
                        icon: "doc",
                        color: .blue
                    )
                    StatCard(
                        title: "Total Folders",
                        value: "\(viewModel.calculateStatistics().totalFolders)",
                        icon: "folder",
                        color: .green
                    )
                    StatCard(
                        title: "Total Size",
                        value: formatBytes(viewModel.calculateStatistics().totalSize),
                        icon: "externaldrive",
                        color: .orange
                    )
                    StatCard(
                        title: "Average Files per Folder",
                        value: String(format: "%.1f", averageFilesPerFolder),
                        icon: "chart.bar",
                        color: .purple
                    )
                }
                
                // Charts
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Type Distribution")
                        .font(.headline)
                    FileTypeChart(nodes: viewModel.nodes)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
                // Size Distribution
                VStack(alignment: .leading, spacing: 12) {
                    Text("Size Distribution")
                        .font(.headline)
                    SizeDistributionChart(nodes: viewModel.nodes)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.headline)
                    ForEach(viewModel.nodes.sorted(by: { $0.modifiedAt > $1.modifiedAt }).prefix(5)) { node in
                        ActivityRow(node: node)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Statistics")
    }
    
    private var averageFilesPerFolder: Double {
        let folders = viewModel.nodes.filter { $0.isDirectory }
        let files = viewModel.nodes.filter { !$0.isDirectory }
        guard !folders.isEmpty else { return 0 }
        return Double(files.count) / Double(folders.count)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - File Type Chart
struct FileTypeChart: View {
    let nodes: [FileNode]
    
    var body: some View {
        let fileTypes = Dictionary(grouping: nodes.filter { !$0.isDirectory }) { node in
            (node.path as NSString).pathExtension.lowercased()
        }
        let topTypes = fileTypes.sorted { $0.value.count > $1.value.count }.prefix(5)
        
        VStack(alignment: .leading, spacing: 8) {
            ForEach(topTypes, id: \.key) { type, files in
                HStack {
                    Text(type.isEmpty ? "No Extension" : ".\(type)")
                        .font(.caption)
                    Spacer()
                    Text("\(files.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(files.count) / CGFloat(nodes.count))
                            .cornerRadius(2)
                    }
                    .frame(height: 4)
                }
            }
        }
    }
}

// MARK: - Size Distribution Chart
struct SizeDistributionChart: View {
    let nodes: [FileNode]
    
    var body: some View {
        let sizeRanges = [
            "0-1KB": nodes.filter { $0.size <= 1024 }.count,
            "1KB-1MB": nodes.filter { $0.size > 1024 && $0.size <= 1_048_576 }.count,
            "1MB-10MB": nodes.filter { $0.size > 1_048_576 && $0.size <= 10_485_760 }.count,
            "10MB-100MB": nodes.filter { $0.size > 10_485_760 && $0.size <= 104_857_600 }.count,
            "100MB+": nodes.filter { $0.size > 104_857_600 }.count
        ]
        
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sizeRanges.keys.sorted()), id: \.self) { range in
                if let count = sizeRanges[range], count > 0 {
                    HStack {
                        Text(range)
                            .font(.caption)
                        Spacer()
                        Text("\(count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geometry.size.width * CGFloat(count) / CGFloat(nodes.count))
                                .cornerRadius(2)
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let node: FileNode
    
    var body: some View {
        HStack {
            Image(systemName: node.systemImageName)
                .foregroundColor(Color(hex: node.colorHex))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.subheadline)
                Text("Modified \(node.formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(node.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Utility Functions
private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}
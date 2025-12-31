// 📁 File: Views/GraphView.swift
// 🎯 INTERACTIVE GRAPH VISUALIZATION

import SwiftUI
import simd

struct GraphView: View {
    @EnvironmentObject var viewModel: GraphViewModel
    @State private var dragOffset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @GestureState private var magnifyBy = 1.0
    @State private var selectedNodeId: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.opacity(0.05)
                    .ignoresSafeArea()
                
                // Graph content
                graphContent(in: geometry)
                    .scaleEffect(scale * magnifyBy)
                    .offset(dragOffset)
                    .gesture(
                        SimultaneousGesture(
                            dragGesture,
                            magnificationGesture
                        )
                    )
                
                // Overlay controls
                VStack {
                    HStack {
                        graphControls
                        Spacer()
                        layoutControls
                    }
                    .padding()
                    
                    Spacer()
                    
                    if viewModel.isLayoutRunning {
                        layoutProgressView
                            .padding()
                    }
                }
            }
        }
        .navigationTitle("Graph View")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Reset Layout") {
                    viewModel.resetLayout()
                }
                
                Button("Export") {
                    exportGraph()
                }
            }
        }
    }
    
    // MARK: - Graph Content
    
    @ViewBuilder
    private func graphContent(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Edges
            if viewModel.configuration.showEdges {
                ForEach(viewModel.visibleEdges, id: \.sourceId) { edge in
                    edgeView(edge: edge, in: geometry)
                }
            }
            
            // Nodes
            ForEach(viewModel.visibleNodes, id: \.id) { node in
                nodeView(node: node, in: geometry)
            }
        }
    }
    
    @ViewBuilder
    private func nodeView(node: FileNode, in geometry: GeometryProxy) -> some View {
        let position = viewModel.layoutPositions[node.id.uuidString] ?? SIMD2<Double>(0.5, 0.5)
        let screenPosition = CGPoint(
            x: position.x * geometry.size.width,
            y: position.y * geometry.size.height
        )
        
        let isSelected = selectedNodeId == node.id.uuidString
        let isHighlighted = viewModel.highlightedNodeIds.contains(node.id.uuidString)
        
        NodeView(
            node: node,
            isSelected: isSelected,
            isHighlighted: isHighlighted,
            showLabel: viewModel.configuration.showLabels
        )
        .position(screenPosition)
        .onTapGesture {
            selectNode(node.id.uuidString)
        }
        .contextMenu {
            nodeContextMenu(for: node)
        }
    }
    
    @ViewBuilder
    private func edgeView(edge: FileEdge, in geometry: GeometryProxy) -> some View {
        if let sourcePos = viewModel.layoutPositions[edge.sourceId],
           let targetPos = viewModel.layoutPositions[edge.targetId] {
            
            let sourcePoint = CGPoint(
                x: sourcePos.x * geometry.size.width,
                y: sourcePos.y * geometry.size.height
            )
            let targetPoint = CGPoint(
                x: targetPos.x * geometry.size.width,
                y: targetPos.y * geometry.size.height
            )
            
            EdgeView(
                from: sourcePoint,
                to: targetPoint,
                strength: edge.strength
            )
        }
    }
    
    // MARK: - Controls
    
    @ViewBuilder
    private var graphControls: some View {
        HStack {
            Button(action: { viewModel.zoom(1.2) }) {
                Image(systemName: "plus.magnifyingglass")
            }
            
            Button(action: { viewModel.zoom(0.8) }) {
                Image(systemName: "minus.magnifyingglass")
            }
            
            Button(action: resetView) {
                Image(systemName: "arrow.clockwise")
            }
        }
        .buttonStyle(.bordered)
    }
    
    @ViewBuilder
    private var layoutControls: some View {
        HStack {
            Button(action: { viewModel.toggleLayoutAnimation() }) {
                Image(systemName: viewModel.isLayoutRunning ? "pause.fill" : "play.fill")
            }
            
            Menu {
                Picker("Layout Quality", selection: $viewModel.configuration.layoutQuality) {
                    Text("Low").tag(GraphViewModel.Configuration.LayoutQuality.low)
                    Text("Medium").tag(GraphViewModel.Configuration.LayoutQuality.medium)
                    Text("High").tag(GraphViewModel.Configuration.LayoutQuality.high)
                    Text("Ultra").tag(GraphViewModel.Configuration.LayoutQuality.ultra)
                }
                
                Toggle("Show Labels", isOn: $viewModel.configuration.showLabels)
                Toggle("Show Edges", isOn: $viewModel.configuration.showEdges)
                Toggle("Animate Layout", isOn: $viewModel.configuration.animateLayout)
            } label: {
                Image(systemName: "gearshape.fill")
            }
        }
        .buttonStyle(.bordered)
    }
    
    @ViewBuilder
    private var layoutProgressView: some View {
        VStack {
            Text("Calculating Layout...")
                .font(.caption)
            
            ProgressView(value: viewModel.layoutProgress)
                .frame(width: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { _ in
                // Optionally snap to grid or apply constraints
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($magnifyBy) { currentState, gestureState, _ in
                gestureState = currentState
            }
            .onEnded { value in
                scale *= value
                scale = max(0.1, min(scale, 5.0)) // Limit zoom range
            }
    }
    
    // MARK: - Actions
    
    private func selectNode(_ nodeId: String) {
        selectedNodeId = nodeId
        viewModel.selectNode(nodeId)
    }
    
    private func resetView() {
        withAnimation(.easeInOut(duration: 0.5)) {
            dragOffset = .zero
            scale = 1.0
        }
        selectedNodeId = nil
        viewModel.selectNode(nil)
    }
    
    private func exportGraph() {
        Task {
            if let data = await viewModel.exportGraph() {
                // Handle export (save to file, share, etc.)
                print("Graph exported: \(data.count) bytes")
            }
        }
    }
    
    @ViewBuilder
    private func nodeContextMenu(for node: FileNode) -> some View {
        Button("Open in Finder") {
            #if os(macOS)
            NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
            #endif
        }
        
        Button(node.isBookmarked ? "Remove Bookmark" : "Add Bookmark") {
            node.isBookmarked.toggle()
        }
        
        Button("Copy Path") {
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(node.path, forType: .string)
            #endif
        }
        
        if node.isDirectory {
            Button("Expand Children") {
                // Load children if not already loaded
            }
        }
    }
}

// MARK: - Node View Component

struct NodeView: View {
    let node: FileNode
    let isSelected: Bool
    let isHighlighted: Bool
    let showLabel: Bool
    
    private var nodeSize: CGFloat {
        let baseSize: CGFloat = 8
        let sizeMultiplier = log10(max(1, Double(node.size) / 1024)) / 10 // Size based on KB
        return baseSize + CGFloat(sizeMultiplier) * 4
    }
    
    private var nodeColor: Color {
        if isSelected {
            return .blue
        } else if isHighlighted {
            return .orange
        } else {
            return Color(hex: node.colorHex)
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Node circle
            Circle()
                .fill(nodeColor)
                .frame(width: nodeSize, height: nodeSize)
                .overlay(
                    Image(systemName: node.systemImageName)
                        .font(.system(size: nodeSize * 0.5))
                        .foregroundColor(.white)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            
            // Label
            if showLabel {
                Text(node.name)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 60)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Edge View Component

struct EdgeView: View {
    let from: CGPoint
    let to: CGPoint
    let strength: Double
    
    private var lineWidth: CGFloat {
        CGFloat(strength * 2.0)
    }
    
    private var opacity: Double {
        min(1.0, strength)
    }
    
    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.gray.opacity(opacity), lineWidth: lineWidth)
    }
}

// MARK: - Preview

struct GraphView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GraphView()
                .environmentObject({
                    let vm = GraphViewModel()
                    vm.loadHierarchy(FileNode.previewHierarchy)
                    return vm
                }())
        }
    }
}
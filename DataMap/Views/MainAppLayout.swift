// 📁 File: Views/MainAppLayout.swift
// 🎯 COMPLETE APP LAYOUT WITH SIDEBAR, TOOLBAR, AND SETTINGS

import SwiftUI
import SwiftData

// MARK: - Main App Container
struct MainAppLayout: View {
    @EnvironmentObject private var viewModel: GraphViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedTab: AppTab = .map
    @State private var selectedProject: Project?
    @State private var isShowingNewProject = false
    @State private var isShowingSettings = false
    @State private var isShowingImport = false
    @State private var isShowingExport = false
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var navigationPath = NavigationPath()
    
    // For search
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad/Mac layout with sidebar
                NavigationSplitView(columnVisibility: $sidebarVisibility) {
                    SidebarView(
                        selectedProject: $selectedProject,
                        selectedTab: $selectedTab,
                        searchText: $searchText,
                        isSearchFocused: _isSearchFocused,
                        onCreateProject: { isShowingNewProject = true },
                        onImport: { isShowingImport = true }
                    )
                    .navigationTitle("GeoMapper Pro")
                    .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 350)
                } content: {
                    ContentColumnView(
                        selectedTab: selectedTab,
                        selectedProject: selectedProject,
                        navigationPath: $navigationPath
                    )
                    .navigationTitle(tabTitle)
                    .navigationBarTitleDisplayMode(.inline)
                } detail: {
                    DetailColumnView(
                        selectedTab: selectedTab,
                        selectedProject: selectedProject,
                        navigationPath: $navigationPath
                    )
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                // iPhone layout with tab bar
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        GraphView()
                            .navigationTitle("Graph View")
                            .toolbar { iPhoneToolbar }
                    }
                    .tabItem {
                        Label("Map", systemImage: "map.fill")
                    }
                    .tag(AppTab.map)
                    
                    NavigationStack {
                        FileBrowserView()
                            .navigationTitle("File Browser")
                    }
                    .tabItem {
                        Label("Browser", systemImage: "folder.fill")
                    }
                    .tag(AppTab.browser)
                    
                    NavigationStack {
                        ProjectsView(selectedProject: $selectedProject)
                            .navigationTitle("Projects")
                    }
                    .tabItem {
                        Label("Projects", systemImage: "globe.desk.fill")
                    }
                    .tag(AppTab.projects)
                    
                    NavigationStack {
                        StatisticsView()
                            .navigationTitle("Statistics")
                    }
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }
                    .tag(AppTab.statistics)
                    
                    NavigationStack {
                        PerformanceSettingsView()
                            .navigationTitle("Settings")
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(AppTab.settings)
                }
            }
        }
        .sheet(isPresented: $isShowingNewProject) {
            NewProjectView()
        }
        .sheet(isPresented: $isShowingImport) {
            ImportView()
        }
        .sheet(isPresented: $isShowingExport) {
            ExportView(project: selectedProject)
        }
        .sheet(isPresented: $isShowingSettings) {
            PerformanceSettingsView()
        }
        .onAppear {
            setupInitialState()
        }
        .overlay(alignment: .center) {
            if viewModel.isLoading {
                GlobalLoadingOverlay()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }
    
    // MARK: - Computed Properties
    private var tabTitle: String {
        switch selectedTab {
        case .map: return "World Map"
        case .browser: return "File Browser"
        case .projects: return "Projects"
        case .statistics: return "Statistics"
        case .settings: return "Settings"
        }
    }
    
    private var iPhoneToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button("New Project", systemImage: "plus") {
                    isShowingNewProject = true
                }
                Button("Import Data", systemImage: "square.and.arrow.down") {
                    isShowingImport = true
                }
                Divider()
                Button("Settings", systemImage: "gear") {
                    isShowingSettings = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    // MARK: - Methods
    private func setupInitialState() {
        // Load last used project
        if selectedProject == nil {
            selectedProject = loadLastProject()
        }
    }
    
    private func loadLastProject() -> Project? {
        // Load from UserDefaults or SwiftData
        // For now, return nil
        return nil
    }
}

// MARK: - App Tabs
enum AppTab: Int, CaseIterable, Identifiable {
    case map = 0
    case browser = 1
    case projects = 2
    case statistics = 3
    case settings = 4
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .map: return "Map"
        case .browser: return "Browser"
        case .projects: return "Projects"
        case .statistics: return "Statistics"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .map: return "map.fill"
        case .browser: return "folder.fill"
        case .projects: return "globe.desk.fill"
        case .statistics: return "chart.bar.fill"
        case .settings: return "gear"
        }
    }
}
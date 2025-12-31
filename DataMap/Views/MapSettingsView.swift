// 📁 File: Views/MapSettingsView.swift
// 🎯 LEGACY MAP SETTINGS - SIMPLIFIED FOR GRAPH ARCHITECTURE

import SwiftUI

struct MapSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Map Settings Deprecated")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Map-based settings are no longer available. This app now uses graph-based visualization. Please use the Graph View settings instead.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .navigationTitle("Map Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct MapSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MapSettingsView()
    }
}
#!/bin/bash

echo "🔍 Verifying Swift file syntax..."

# Check key files for syntax errors
files=(
    "DataMap/DataMapApp.swift"
    "DataMap/ContentView.swift"
    "DataMap/Views/MainAppLayout.swift"
    "DataMap/Views/GraphView.swift"
    "DataMap/Views/UtilityViews.swift"
    "DataMap/ViewModels/GraphViewModel.swift"
    "DataMap/Engine/GraphLayoutEngine.swift"
    "DataMap/Models/FileNode.swift"
    "DataMap/Rendering/MetalRenderer.swift"
)

for file in "${files[@]}"; do
    echo "Checking $file..."
    if swiftc -parse "$file" 2>/dev/null; then
        echo "✅ $file - OK"
    else
        echo "❌ $file - SYNTAX ERROR"
        swiftc -parse "$file"
    fi
done

echo "🎉 Syntax verification complete!"
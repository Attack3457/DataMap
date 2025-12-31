// 📁 File: Rendering/GraphShaders.metal
// 🎯 GRAPH VISUALIZATION SHADERS

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct Uniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float2 viewportSize;
    float scale;
    float time;
    float selectedNodeId;
    float highlightRadius;
};

struct Vertex {
    float2 position;    // Graph coordinates (0-1)
    float4 color;
    float size;
    float nodeType;
    float isSelected;
    float isHighlighted;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 uv;
    float size [[point_size]];
    float nodeType;
    float isSelected;
    float isHighlighted;
    float pulse;
};

// MARK: - Vertex Shader

vertex VertexOut graph_vertex_main(const device Vertex* vertices [[buffer(0)]],
                                  constant Uniforms& uniforms [[buffer(1)]],
                                  uint vid [[vertex_id]]) {
    VertexOut out;
    Vertex v = vertices[vid];
    
    // Convert graph coordinates to screen space
    // Graph coordinates are already 0-1, just scale to viewport
    float2 screenPos = v.position * uniforms.viewportSize;
    out.position = float4(screenPos, 0.0, 1.0);
    
    out.color = v.color;
    out.size = v.size * uniforms.scale;
    out.nodeType = v.nodeType;
    out.isSelected = v.isSelected;
    out.isHighlighted = v.isHighlighted;
    out.uv = float2(0.5, 0.5); // For point rendering
    
    // Pulsing animation for selected/highlighted nodes
    float pulse = sin(uniforms.time * 2.0) * 0.1 + 1.0;
    out.pulse = (v.isSelected > 0.5 || v.isHighlighted > 0.5) ? pulse : 1.0;
    out.size *= out.pulse;
    
    return out;
}

// MARK: - Fragment Shader for Nodes

fragment float4 graph_fragment_main(VertexOut inVertex [[stage_in]],
                                   float2 pointCoord [[point_coord]]) {
    // Circle rendering
    float2 center = float2(0.5, 0.5);
    float distance = length(pointCoord - center);
    
    // Different rendering based on node type
    float alpha;
    
    if (inVertex.nodeType == 0.0) { // Directory
        // Folders have a different shape
        float folderShape = 1.0 - smoothstep(0.3, 0.5, distance);
        float tab = 1.0 - smoothstep(0.1, 0.3, abs(pointCoord.x - 0.5));
        alpha = max(folderShape, tab * 0.5);
        
        // Add glow for directories
        float glow = 1.0 - smoothstep(0.1, 0.4, distance);
        alpha = max(alpha, glow * 0.3);
    } else { // File
        // Regular circle for files
        alpha = 1.0 - smoothstep(0.4, 0.5, distance);
    }
    
    // Highlight selected nodes
    if (inVertex.isSelected > 0.5) {
        float highlightRing = 1.0 - smoothstep(0.45, 0.55, distance);
        alpha = max(alpha, highlightRing * 0.8);
    }
    
    // Apply alpha
    float4 color = inVertex.color;
    color.a = color.a * alpha;
    
    // Discard fully transparent pixels
    if (color.a < 0.01) {
        discard_fragment();
    }
    
    return color;
}

// MARK: - Edge Shaders

struct EdgeVertex {
    float2 startPos;
    float2 endPos;
    float4 color;
    float width;
    float isDashed;
};

struct EdgeOut {
    float4 position [[position]];
    float4 color;
    float2 uv;
    float width;
    float isDashed;
};

vertex EdgeOut edge_vertex_main(const device EdgeVertex* edges [[buffer(0)]],
                               constant Uniforms& uniforms [[buffer(1)]],
                               uint vid [[vertex_id]],
                               uint instanceId [[instance_id]]) {
    EdgeOut out;
    EdgeVertex edge = edges[instanceId];
    
    // Generate a quad along the edge
    // We'll expand to a line in geometry shader or use instancing
    float2 startScreen = edge.startPos * uniforms.viewportSize;
    float2 endScreen = edge.endPos * uniforms.viewportSize;
    
    // Simplified: just draw a line between points
    float t = float(vid % 2) / 2.0;
    float2 pos = mix(startScreen, endScreen, t);
    
    out.position = float4(pos, 0.0, 1.0);
    out.color = edge.color;
    out.width = edge.width;
    out.isDashed = edge.isDashed;
    out.uv = float2(t, 0.0);
    
    return out;
}

fragment float4 edge_fragment_main(EdgeOut inEdge [[stage_in]]) {
    // Dashed line effect
    if (inEdge.isDashed > 0.5) {
        float dash = fract(inEdge.uv.x * 10.0);
        if (dash > 0.5) {
            discard_fragment();
        }
    }
    
    // Fade out near ends
    float fade = 1.0 - smoothstep(0.45, 0.5, abs(inEdge.uv.x - 0.5));
    
    float4 color = inEdge.color;
    color.a *= fade;
    
    if (color.a < 0.01) {
        discard_fragment();
    }
    
    return color;
}

// MARK: - Advanced Node Rendering

// Bezier curve for smooth edges
float2 bezier_curve(float2 p0, float2 p1, float2 p2, float2 p3, float t) {
    float u = 1.0 - t;
    float tt = t * t;
    float uu = u * u;
    float uuu = uu * u;
    float ttt = tt * t;
    
    float2 p = uuu * p0;
    p += 3.0 * uu * t * p1;
    p += 3.0 * u * tt * p2;
    p += ttt * p3;
    
    return p;
}

// Distance to line segment
float distance_to_line(float2 p, float2 a, float2 b) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Advanced edge rendering with curves
vertex EdgeOut curved_edge_vertex_main(const device EdgeVertex* edges [[buffer(0)]],
                                      constant Uniforms& uniforms [[buffer(1)]],
                                      uint vid [[vertex_id]],
                                      uint instanceId [[instance_id]]) {
    EdgeOut out;
    EdgeVertex edge = edges[instanceId];
    
    float2 startScreen = edge.startPos * uniforms.viewportSize;
    float2 endScreen = edge.endPos * uniforms.viewportSize;
    
    // Create control points for bezier curve
    float2 direction = normalize(endScreen - startScreen);
    float2 perpendicular = float2(-direction.y, direction.x);
    float distance = length(endScreen - startScreen);
    
    // Control points for curved edge
    float2 p0 = startScreen;
    float2 p1 = startScreen + direction * distance * 0.3 + perpendicular * distance * 0.1;
    float2 p2 = endScreen - direction * distance * 0.3 + perpendicular * distance * 0.1;
    float2 p3 = endScreen;
    
    // Generate points along the curve
    float t = float(vid) / 32.0; // 32 segments per edge
    float2 pos = bezier_curve(p0, p1, p2, p3, t);
    
    out.position = float4(pos, 0.0, 1.0);
    out.color = edge.color;
    out.width = edge.width;
    out.isDashed = edge.isDashed;
    out.uv = float2(t, 0.0);
    
    return out;
}

// Node with icon rendering
fragment float4 icon_node_fragment_main(VertexOut inVertex [[stage_in]],
                                       float2 pointCoord [[point_coord]]) {
    float2 center = float2(0.5, 0.5);
    float distance = length(pointCoord - center);
    
    // Base circle
    float alpha = 1.0 - smoothstep(0.4, 0.5, distance);
    
    // Icon rendering based on node type
    if (inVertex.nodeType == 0.0) { // Directory
        // Folder icon
        float2 uv = pointCoord - center + 0.5;
        
        // Folder body
        float folderBody = step(0.2, uv.x) * step(uv.x, 0.8) * 
                          step(0.3, uv.y) * step(uv.y, 0.7);
        
        // Folder tab
        float folderTab = step(0.2, uv.x) * step(uv.x, 0.5) * 
                         step(0.7, uv.y) * step(uv.y, 0.8);
        
        alpha = max(alpha * 0.3, max(folderBody, folderTab));
    } else { // File
        // Document icon
        float2 uv = pointCoord - center + 0.5;
        
        // Document body
        float docBody = step(0.25, uv.x) * step(uv.x, 0.75) * 
                       step(0.2, uv.y) * step(uv.y, 0.8);
        
        // Document corner fold
        float cornerX = step(0.6, uv.x) * step(uv.x, 0.75);
        float cornerY = step(0.65, uv.y) * step(uv.y, 0.8);
        float corner = cornerX * cornerY;
        
        alpha = max(alpha * 0.3, max(docBody, corner * 0.7));
    }
    
    // Selection highlight
    if (inVertex.isSelected > 0.5) {
        float ring = 1.0 - smoothstep(0.45, 0.55, distance);
        alpha = max(alpha, ring * 0.6);
    }
    
    float4 color = inVertex.color;
    color.a *= alpha;
    
    if (color.a < 0.01) {
        discard_fragment();
    }
    
    return color;
}
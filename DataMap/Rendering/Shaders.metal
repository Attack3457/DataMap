// 📁 File: Rendering/Shaders.metal
// 🎯 METAL SHADERS FOR GPU RENDERING

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct Uniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float time;
    float zoomLevel;
    float2 viewportSize;
    float nodeScale;
};

struct Vertex {
    float2 position;
    float4 color;
    float size;
    uint nodeID;
    uint nodeType;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float size [[point_size]];
    uint nodeID [[flat]];
    uint nodeType [[flat]];
};

// MARK: - Vertex Shader

vertex VertexOut vertex_main(const device Vertex* vertices [[buffer(0)]],
                            constant Uniforms& uniforms [[buffer(1)]],
                            uint vid [[vertex_id]]) {
    VertexOut out;
    
    Vertex v = vertices[vid];
    
    // Transform position from world coordinates to screen space
    float4 worldPos = float4(v.position.x / 180.0, v.position.y / 90.0, 0.0, 1.0);
    float4 viewPos = uniforms.viewMatrix * worldPos;
    out.position = uniforms.projectionMatrix * viewPos;
    
    // Pass through color and size
    out.color = v.color;
    out.size = v.size * uniforms.nodeScale;
    out.nodeID = v.nodeID;
    out.nodeType = v.nodeType;
    
    // Simple animation
    float nodeIDFloat = float(v.nodeID);
    float pulse = sin(uniforms.time * 2.0 + fmod(nodeIDFloat, 100.0) * 0.1) * 0.1 + 1.0;
    out.size = out.size * pulse;
    
    return out;
}

// MARK: - Fragment Shader

fragment float4 fragment_main(VertexOut inVertex [[stage_in]],
                             float2 pointCoord [[point_coord]]) {
    // Create circular points
    float2 center = float2(0.5, 0.5);
    float distance = length(pointCoord - center);
    
    // Smooth circular falloff
    float alpha = 1.0 - smoothstep(0.3, 0.5, distance);
    
    // Add glow effect for directories
    if (inVertex.nodeType == 1) {
        float glow = 1.0 - smoothstep(0.1, 0.8, distance);
        alpha = max(alpha, glow * 0.3);
    }
    
    // Apply alpha to color
    float4 color = inVertex.color;
    color.a = color.a * alpha;
    
    // Discard fully transparent pixels
    if (color.a < 0.01) {
        discard_fragment();
    }
    
    return color;
}
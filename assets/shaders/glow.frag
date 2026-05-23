#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uIntensity; // 0..1 overall amplitude
uniform float uHotCore;   // 0..1 hot inner spike size
uniform vec3 uColor;      // base hue

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec2 d = uv - 0.5;
    float r = length(d);

    // Hot core — sharp spike near center
    float core = exp(-r * mix(20.0, 8.0, uHotCore));

    // Mid bloom
    float mid = exp(-r * 5.0) * 0.55;

    // Outer halo (soft falloff)
    float outer = exp(-r * 2.1) * 0.30;

    float sum = (core + mid + outer) * uIntensity;

    // Slight chromatic split in the halo for premium-indie feel
    float ang = atan(d.y, d.x);
    float ringR = exp(-pow((r - 0.32) * 7.0, 2.0)) * uIntensity * 0.45;
    float chromaR = ringR * 1.0;
    float chromaG = exp(-pow((r - 0.30) * 7.0, 2.0)) * uIntensity * 0.35;
    float chromaB = exp(-pow((r - 0.28) * 7.0, 2.0)) * uIntensity * 0.30;

    vec3 col = uColor * sum;
    col.r += chromaR * 0.35;
    col.g += chromaG * 0.20;
    col.b += chromaB * 0.10;

    // Premultiplied alpha output for additive-friendly compositing
    float alpha = clamp(sum * 1.4, 0.0, 1.0);
    fragColor = vec4(col, alpha);
}

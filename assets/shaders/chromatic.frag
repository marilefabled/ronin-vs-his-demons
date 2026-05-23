#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uIntensity; // 0..1
uniform float uTime;      // for jitter

out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec2 d = uv - 0.5;
    float r = length(d);

    // Edge-only effect — strongest at corners, zero at center
    float edge = smoothstep(0.20, 0.85, r);
    float strength = edge * uIntensity;

    // Three-channel ring split — RGB ghosts at slightly different radii.
    float ringR = exp(-pow((r - 0.55) * 5.5, 2.0));
    float ringG = exp(-pow((r - 0.48) * 5.5, 2.0));
    float ringB = exp(-pow((r - 0.41) * 5.5, 2.0));

    // Tiny jitter to feel alive
    float j = (hash(FlutterFragCoord().xy + uTime * 9.0) - 0.5) * 0.04;

    vec3 col;
    col.r = ringR * strength + j * 0.05;
    col.g = ringG * strength * 0.4;
    col.b = ringB * strength * 0.7;

    float alpha = max(max(col.r, col.g), col.b);
    fragColor = vec4(col, alpha);
}

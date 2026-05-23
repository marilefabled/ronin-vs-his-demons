#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 5; i++) {
        v += amp * noise(p);
        p *= 2.05;
        amp *= 0.5;
    }
    return v;
}

void main() {
    vec2 fragPos = FlutterFragCoord().xy;
    vec2 uv = fragPos / uSize;

    // Warm beige base with subtle vertical wash
    vec3 base = mix(
        vec3(0.953, 0.925, 0.859),  // top — slightly cooler off-white
        vec3(0.906, 0.871, 0.784),  // bottom — warmer khaki
        uv.y
    );

    // Fine paper grain — high-frequency, low amplitude
    float grain = (hash(fragPos * 0.7) - 0.5) * 0.05;
    grain += (hash(fragPos * 1.4 + vec2(13.0, 7.0)) - 0.5) * 0.025;
    base += grain;

    // Mid-frequency fiber texture — gives the paper its "pulp"
    float fiber = noise(fragPos * 0.012);
    base = mix(base, base * 0.94, fiber * 0.18);

    // Large drifting ink wash veins
    vec2 q = uv * 3.4 + vec2(uTime * 0.013, uTime * 0.009);
    float wash = fbm(q);
    wash = smoothstep(0.42, 0.85, wash);
    base = mix(base, vec3(0.282, 0.226, 0.157), wash * 0.18);

    // Slower deeper wash drifting opposite
    vec2 q2 = uv * 1.7 - vec2(uTime * 0.006, uTime * 0.004);
    float wash2 = fbm(q2);
    wash2 = smoothstep(0.55, 0.96, wash2);
    base = mix(base, vec3(0.184, 0.149, 0.110), wash2 * 0.22);

    // Subtle warm tint pockets (ink soaking through from underside)
    vec2 q3 = uv * 0.8 + vec2(uTime * 0.003, -uTime * 0.002);
    float pocket = fbm(q3);
    pocket = smoothstep(0.62, 0.92, pocket);
    base = mix(base, vec3(0.620, 0.428, 0.235), pocket * 0.10);

    // Vignette — focus center, darken edges
    float dist = length(uv - 0.5);
    float vignette = smoothstep(0.92, 0.32, dist);
    base *= mix(0.72, 1.0, vignette);

    // Final very subtle blue cast in shadows for cinematic feel
    base.b += (1.0 - vignette) * 0.02;

    fragColor = vec4(base, 1.0);
}

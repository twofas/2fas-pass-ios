#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float vcHash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float vcNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    float a = vcHash(i);
    float b = vcHash(i + float2(1.0, 0.0));
    float c = vcHash(i + float2(0.0, 1.0));
    float d = vcHash(i + float2(1.0, 1.0));

    float2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x)
         + (c - a) * u.y * (1.0 - u.x)
         + (d - b) * u.x * u.y;
}

static float vcFbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;

    for (int i = 0; i < 5; i++) {
        value += amplitude * vcNoise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// MARK: - Color Effect: Violet Cloud (Siri-based, purple palette)

[[ stitchable ]]
half4 violetCloud(float2 position, float2 size, float time,
                  float speed, float scale, float swirlStrength, float coreBright, float glowAmount) {
    float2 uv = position / size;
    uv = uv * 2.0 - 1.0;

    float aspect = size.x / size.y;
    uv.x *= aspect;

    float r = length(uv);
    float angle = atan2(uv.y, uv.x);

    float t = time * speed;

    float n1 = vcFbm(uv * scale + float2(t * 0.18, -t * 0.10));
    float n2 = vcFbm(uv * (scale * 1.7) + float2(-t * 0.12, t * 0.16));
    float n3 = vcFbm(float2(angle * 1.8, r * 3.0 - t * 0.25));

    float blob = 1.0 - smoothstep(0.25, 0.95, r);
    float swirl = 0.5 + 0.5 * sin(angle * 3.0 - t * 1.4 + n2 * 2.0);

    float density = blob;
    density += n1 * 0.45;
    density += n2 * 0.30;
    density += n3 * 0.20;
    density += swirl * swirlStrength;

    density = smoothstep(0.55, 1.15, density);

    float core = 1.0 - smoothstep(0.0, 0.45, r);
    float glw = 1.0 - smoothstep(0.2, 1.1, r);

    // Purple palette: #4C008F, #6400BC, #8800FF
    float3 colorA = float3(0.298, 0.0, 0.561);  // #4C008F
    float3 colorB = float3(0.392, 0.0, 0.737);  // #6400BC
    float3 colorC = float3(0.533, 0.0, 1.0);    // #8800FF

    float mix1 = 0.5 + 0.5 * sin(t * 0.9 + uv.x * 2.5 + n1 * 2.0);
    float mix2 = 0.5 + 0.5 * sin(t * 1.2 + uv.y * 2.8 + n2 * 2.0);

    float3 baseColor = mix(colorA, colorB, mix1);
    baseColor = mix(baseColor, colorC, mix2 * 0.55);

    float3 finalColor = baseColor * density;
    finalColor += baseColor * core * coreBright;
    finalColor += float3(0.15, 0.0, 0.30) * glw * glowAmount;

    float alpha = density * 0.85 + glw * glowAmount * 0.5;
    alpha = clamp(alpha, 0.0, 1.0);

    return half4(half3(finalColor), half(alpha));
}

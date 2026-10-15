#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 atlasMetrics; // minimum pixels, step, cell size, displayed physical pixels
};
layout(binding = 1) uniform sampler2D atlas;

vec4 level(float index) {
    float pixels = atlasMetrics.x + index * atlasMetrics.y;
    vec2 origin = vec2(mod(index, 3.0), floor(index / 3.0)) * atlasMetrics.z + vec2(2.0);
    return texture(atlas, (origin + qt_TexCoord0 * pixels) / (atlasMetrics.z * 3.0));
}

void main() {
    float lod = clamp((atlasMetrics.w - atlasMetrics.x) / atlasMetrics.y, 0.0, 8.0);
    float lower = floor(lod);
    // Adjacent levels were independently Lanczos-filtered from the original.
    // Blend levels on the GPU: no image reloads or CPU resampling during hover.
    fragColor = mix(level(lower), level(min(lower + 1.0, 8.0)), fract(lod)) * qt_Opacity;
}

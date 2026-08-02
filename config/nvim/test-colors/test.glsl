// Single-line comment
/*
 * Multi-line comment
 * GLSL syntax showcase
 */

#version 460 core

// Preprocessor and extensions
#extension GL_EXT_ray_tracing : require
#extension GL_GOOGLE_include_directive : enable

#include "shared.glsl"

#define WORKGROUP_SIZE 16
#define SQR(x) ((x) * (x))

#ifndef MAX_STEPS
#define MAX_STEPS 64
#endif

// Compute layout qualifier
layout(local_size_x = WORKGROUP_SIZE, local_size_y = WORKGROUP_SIZE, local_size_z = 1) in;

// Constants
const float PI = 3.14159265358979;
const uint INVALID_INDEX = 0xFFFFFFFFu;
const vec3 UP_AXIS = vec3(0.0, 1.0, 0.0);

// Interface blocks
layout(std140, binding = 0) uniform FrameData
{
    mat4  viewProjection;
    mat4  inverseView;
    vec3  cameraPosition;
    float elapsedTime;
} frame;

layout(std430, binding = 1) buffer VisibilityBuffer
{
    uint visibleCount;
    uint indices[];
} visibility;

layout(push_constant) uniform PushConstants
{
    uvec2 resolution;
    float exposure;
} pc;

// Samplers and images
layout(binding = 2) uniform sampler2D albedoMap;
layout(binding = 3) uniform samplerCube environmentMap;
layout(binding = 4) uniform sampler2DShadow shadowMap;
layout(rgba16f, binding = 5) uniform writeonly image2D outputImage;

// Stage inputs and outputs
layout(location = 0) in vec3 vWorldPosition;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec2 vTexCoord;
layout(location = 0) out vec4 fragColor;

// User-defined struct
struct Light
{
    vec3  position;
    float radius;
    vec3  color;
    uint  flags;
};

// Function with in/out/inout parameter qualifiers
float attenuate(in float distanceSq, in float radius)
{
    float ratio = distanceSq / SQR(radius);
    return clamp(1.0 - ratio, 0.0, 1.0);
}

void decompose(in mat4 m, out vec3 translation, inout float scale)
{
    translation = vec3(m[3][0], m[3][1], m[3][2]);
    scale *= length(vec3(m[0][0], m[1][0], m[2][0]));
}

vec3 fresnel(vec3 f0, float cosTheta)
{
    return f0 + (1.0 - f0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

void main()
{
    // Builtin variables
    uvec3 threadId = gl_GlobalInvocationID;
    uint  localIndex = gl_LocalInvocationIndex;

    if (threadId.x >= pc.resolution.x || threadId.y >= pc.resolution.y)
    {
        return;
    }

    vec4 albedo = texture(albedoMap, vTexCoord);

    // Discard on alpha test
    if (albedo.a < 0.5)
    {
        discard;
    }

    vec3 accumulated = vec3(0.0);

    for (uint i = 0u; i < visibility.visibleCount; ++i)
    {
        uint index = visibility.indices[i];

        if (index == INVALID_INDEX)
        {
            continue;
        }

        vec3  toLight = frame.cameraPosition - vWorldPosition;
        float distSq  = dot(toLight, toLight);
        float ndotl   = max(dot(normalize(vNormal), normalize(toLight)), 0.0);

        accumulated += albedo.rgb * ndotl * attenuate(distSq, 10.0);
    }

    // Operators: bitwise, arithmetic, comparison, ternary
    uint mask    = 0xFFu & (threadId.x << 2);
    bool visible = (mask != 0u) && (threadId.y >= 4u) || (mask == 0x10u);
    float weight = visible ? 1.0 : 0.0;

    accumulated *= fresnel(albedo.rgb, weight) * pc.exposure;

    imageStore(outputImage, ivec2(threadId.xy), vec4(accumulated, albedo.a));
    fragColor = vec4(accumulated, albedo.a);
}

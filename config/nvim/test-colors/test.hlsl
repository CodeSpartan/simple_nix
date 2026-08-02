// Single-line comment
/*
 * Multi-line comment
 * HLSL syntax showcase
 */

// Preprocessor directives
#include "common.hlsli"

#define MAX_LIGHTS 8
#define SQR(x) ((x) * (x))

#pragma pack_matrix(row_major)

#ifndef USE_PBR
#define USE_PBR 1
#endif

// Constants
static const float PI = 3.14159265358979f;
static const uint TILE_SIZE = 16u;
static const float3 UP_AXIS = float3(0.0f, 1.0f, 0.0f);

// Constant buffers with explicit register bindings
cbuffer FrameConstants : register(b0, space0)
{
    float4x4 viewProjection;
    float4x4 inverseView;
    float3   cameraPosition;
    float    elapsedTime;
};

cbuffer LightConstants : register(b1)
{
    uint  activeLightCount;
    float ambientIntensity;
};

// Resource declarations
Texture2D<float4>          albedoMap     : register(t0);
Texture2DArray<float>      shadowMaps    : register(t1);
TextureCube<float3>        environmentMap : register(t2);
StructuredBuffer<Light>    lights        : register(t3);
RWStructuredBuffer<uint>   visibleIndices : register(u0);
RWTexture2D<float4>        outputTarget  : register(u1);
SamplerState               linearSampler : register(s0);
SamplerComparisonState     shadowSampler : register(s1);

// User-defined types
struct Light
{
    float3 position;
    float  radius;
    float3 color;
    uint   flags;
};

struct VertexInput
{
    float3 position : POSITION;
    float3 normal   : NORMAL;
    float2 texCoord : TEXCOORD0;
    uint   instance : SV_InstanceID;
};

struct VertexOutput
{
    float4 clipPosition : SV_Position;
    float3 worldNormal  : NORMAL;
    float2 texCoord     : TEXCOORD0;
    nointerpolation uint materialId : TEXCOORD1;
};

// Enumerated flags
enum LightFlags
{
    LIGHT_NONE     = 0,
    LIGHT_CASTS    = 1 << 0,
    LIGHT_VOLUMETRIC = 1 << 1,
};

// Free function with in/out/inout parameter modifiers
float3 Fresnel(in float3 f0, in float cosTheta)
{
    return f0 + (1.0f - f0) * pow(saturate(1.0f - cosTheta), 5.0f);
}

void DecomposeTransform(in float4x4 m, out float3 translation, inout float scale)
{
    translation = float3(m._14, m._24, m._34);
    scale *= length(float3(m._11, m._21, m._31));
}

// Templated helper
template<typename T>
T LerpClamped(T a, T b, float t)
{
    return lerp(a, b, saturate(t));
}

// Vertex stage
[shader("vertex")]
VertexOutput VSMain(VertexInput input)
{
    VertexOutput output;

    float4 worldPosition = float4(input.position, 1.0f);
    output.clipPosition  = mul(viewProjection, worldPosition);
    output.worldNormal   = normalize(input.normal);
    output.texCoord      = input.texCoord;
    output.materialId    = input.instance % MAX_LIGHTS;

    return output;
}

// Pixel stage with early depth-stencil
[shader("pixel")]
[earlydepthstencil]
float4 PSMain(VertexOutput input) : SV_Target0
{
    float4 albedo = albedoMap.Sample(linearSampler, input.texCoord);

    // Alpha test
    if (albedo.a < 0.5f)
    {
        discard;
    }

    float3 accumulated = albedo.rgb * ambientIntensity;

    [loop]
    for (uint i = 0u; i < activeLightCount; ++i)
    {
        Light light = lights[i];

        float3 toLight = light.position - cameraPosition;
        float  distSq  = dot(toLight, toLight);

        [branch]
        if (distSq > SQR(light.radius))
        {
            continue;
        }

        float ndotl = saturate(dot(input.worldNormal, normalize(toLight)));
        accumulated += light.color * ndotl * Fresnel(albedo.rgb, ndotl);
    }

    return float4(accumulated, albedo.a);
}

// Compute stage
[shader("compute")]
[numthreads(TILE_SIZE, TILE_SIZE, 1)]
void CSCull(uint3 threadId  : SV_DispatchThreadID,
            uint3 groupId   : SV_GroupID,
            uint  groupIndex : SV_GroupIndex)
{
    groupshared uint tileVisibleCount;

    if (groupIndex == 0u)
    {
        tileVisibleCount = 0u;
    }

    GroupMemoryBarrierWithGroupSync();

    // Operators: bitwise, arithmetic, comparison, ternary
    uint mask   = 0xFFu & (threadId.x << 2);
    bool inside = (mask != 0u) && (threadId.y >= 4u) || (mask == 0x10u);
    uint slot   = inside ? threadId.x : ~0u;

    InterlockedAdd(tileVisibleCount, inside ? 1u : 0u);
    GroupMemoryBarrierWithGroupSync();

    visibleIndices[groupId.x] = tileVisibleCount;
    outputTarget[threadId.xy] = float4(asfloat(slot), PI, 1e-3f, 1.0f);
}

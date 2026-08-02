// Single-line comment
/*
 * Multi-line comment
 * Slang syntax showcase
 */

// Module system
module raytracing;

import glsl;
__exported import common;

implementing scene;

// Preprocessor still applies
#define MAX_BOUNCES 4

// Constants
static const float EPSILON = 1e-5f;
static const uint  INVALID_INDEX = 0xFFFFFFFFu;

namespace render
{

// Interfaces and associated types
interface IMaterial
{
    associatedtype Sample : ISampleable;

    float3 evaluate(float3 wi, float3 wo);
    Sample createSample(float2 uv);

    // Static requirement
    static This defaultInstance();
}

interface ISampleable
{
    property float pdf { get; }
}

// Enumerations
enum ScatterKind
{
    Diffuse,
    Specular,
    Transmissive,
}

// Generic struct with a constraint
struct Lambertian<T : __BuiltinFloatingPointType> : IMaterial
{
    typealias Sample = LambertSample;

    vector<T, 3> albedo;
    T            roughness;

    // Initializer
    __init(vector<T, 3> color)
    {
        albedo = color;
        roughness = T(1);
    }

    // Computed property
    property vector<T, 3> tint
    {
        get { return albedo * roughness; }
        set { albedo = newValue; }
    }

    float3 evaluate(float3 wi, float3 wo)
    {
        let cosTheta = max(dot(wi, wo), 0.0f);
        return float3(albedo) * cosTheta / 3.14159265f;
    }

    LambertSample createSample(float2 uv)
    {
        var sample = LambertSample();
        sample.direction = normalize(float3(uv, 1.0f));
        return sample;
    }

    static This defaultInstance()
    {
        return This(vector<T, 3>(T(1)));
    }
}

struct LambertSample : ISampleable
{
    float3 direction;

    property float pdf { get { return 1.0f / (4.0f * 3.14159265f); } }
}

// Extensions on existing types
extension float3
{
    float luminance()
    {
        return dot(this, float3(0.2126f, 0.7152f, 0.0722f));
    }
}

// Generic free function with a where clause
[ForceInline]
T saturateTo<T>(T value, T upper)
    where T : IComparable
{
    return value > upper ? upper : value;
}

// Differentiable function
[Differentiable]
float smoothFalloff(no_diff float radius, float distance)
{
    let ratio = distance / radius;
    return 1.0f - saturate(ratio * ratio);
}

} // namespace render

// Parameter blocks and resources
ParameterBlock<SceneData> gScene;
ConstantBuffer<CameraData> gCamera;
StructuredBuffer<render::LambertSample> gSamples;
RWTexture2D<float4> gOutput;
SamplerState gSampler;

struct SceneData
{
    float4x4 worldToClip;
    uint     primitiveCount;
};

struct CameraData
{
    float3 origin;
    float  aperture;
};

// Compute entry point
[shader("compute")]
[numthreads(8, 8, 1)]
void computeMain(uint3 threadId : SV_DispatchThreadID,
                 uniform float exposure)
{
    uint2 pixel = threadId.xy;

    if (pixel.x >= gScene.primitiveCount)
    {
        return;
    }

    var material = render::Lambertian<float>(float3(0.8f, 0.4f, 0.2f));
    var radiance = float3(0.0f);

    [unroll]
    for (int bounce = 0; bounce < MAX_BOUNCES; ++bounce)
    {
        let sample = material.createSample(float2(pixel) * EPSILON);
        radiance += material.evaluate(sample.direction, gCamera.origin) * sample.pdf;
    }

    // Optional and null handling
    Optional<float> maybeDepth = none;
    if (let depth = maybeDepth)
    {
        radiance *= depth;
    }

    // Operators: bitwise, arithmetic, comparison, ternary
    uint packed  = (pixel.x << 16) | (pixel.y & 0xFFFFu);
    bool visible = (packed != INVALID_INDEX) && (radiance.luminance() > EPSILON);

    gOutput[pixel] = visible ? float4(radiance * exposure, 1.0f)
                             : float4(0.0f, 0.0f, 0.0f, 1.0f);
}

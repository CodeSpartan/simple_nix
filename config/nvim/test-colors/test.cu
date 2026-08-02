// Single-line comment
/*
 * Multi-line comment
 * CUDA syntax showcase
 */

#include <cooperative_groups.h>
#include <cuda_fp16.h>
#include <cuda_runtime.h>
#include <mma.h>

#include <cstdio>
#include <vector>

#define TILE_DIM 32
#define CHECK(expr) checkCuda((expr), __FILE__, __LINE__)

namespace cg = cooperative_groups;

namespace kernels {

// Constants
constexpr int   WARP_SIZE = 32;
constexpr float EPSILON = 1e-6f;

// Device-side constant memory
__constant__ float gFilterWeights[TILE_DIM];

// Device global
__device__ unsigned int gCounter = 0u;

// Host helper
inline void checkCuda(cudaError_t status, const char* file, int line)
{
    if (status != cudaSuccess) {
        std::fprintf(stderr, "CUDA error %s at %s:%d\n", cudaGetErrorString(status), file, line);
    }
}

// Device function
__device__ __forceinline__ float warpReduceSum(float value)
{
    for (int offset = WARP_SIZE / 2; offset > 0; offset >>= 1) {
        value += __shfl_down_sync(0xFFFFFFFFu, value, offset);
    }
    return value;
}

// Templated device function
template <typename T>
__device__ T clampTo(T value, T lo, T hi)
{
    return value < lo ? lo : (value > hi ? hi : value);
}

// Kernel with shared memory and launch bounds
__global__ __launch_bounds__(256, 4) void transposeTiled(const float* __restrict__ input,
                                                         float* __restrict__ output,
                                                         int width,
                                                         int height)
{
    __shared__ float tile[TILE_DIM][TILE_DIM + 1];

    unsigned int x = blockIdx.x * TILE_DIM + threadIdx.x;
    unsigned int y = blockIdx.y * TILE_DIM + threadIdx.y;

    if (x < width && y < height) {
        tile[threadIdx.y][threadIdx.x] = input[y * width + x];
    }

    __syncthreads();

    x = blockIdx.y * TILE_DIM + threadIdx.x;
    y = blockIdx.x * TILE_DIM + threadIdx.y;

    if (x < height && y < width) {
        output[y * height + x] = tile[threadIdx.x][threadIdx.y];
    }
}

// Kernel using cooperative groups and atomics
__global__ void reduceAndCount(const float* __restrict__ data, float* __restrict__ result, int n)
{
    cg::thread_block block = cg::this_thread_block();

    float sum = 0.0f;

    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < n; i += gridDim.x * blockDim.x) {
        sum += clampTo(data[i], -1.0f, 1.0f);
    }

    sum = warpReduceSum(sum);

    if (block.thread_rank() % WARP_SIZE == 0) {
        atomicAdd(result, sum);
        atomicAdd(&gCounter, 1u);
    }
}

}  // namespace kernels

int main()
{
    const int n = 1 << 20;

    float* deviceInput = nullptr;
    float* deviceOutput = nullptr;

    CHECK(cudaMalloc(&deviceInput, n * sizeof(float)));
    CHECK(cudaMalloc(&deviceOutput, n * sizeof(float)));

    std::vector<float> hostInput(n, 0.5f);
    CHECK(cudaMemcpy(deviceInput, hostInput.data(), n * sizeof(float), cudaMemcpyHostToDevice));

    cudaStream_t stream;
    CHECK(cudaStreamCreate(&stream));

    dim3 blockDim(TILE_DIM, TILE_DIM, 1);
    dim3 gridDim((n + TILE_DIM - 1) / TILE_DIM, 1, 1);

    // Triple-angle-bracket launch configuration
    kernels::transposeTiled<<<gridDim, blockDim, 0, stream>>>(deviceInput, deviceOutput, 1024, 1024);
    kernels::reduceAndCount<<<256, 256, 0, stream>>>(deviceInput, deviceOutput, n);

    CHECK(cudaStreamSynchronize(stream));

    // Operators: bitwise, arithmetic, comparison, ternary
    unsigned int mask = 0xFFu & (n >> 4);
    bool         ok   = (mask != 0u) && (n >= 1024) || (mask == 0x10u);
    float        norm = ok ? 1.0f / static_cast<float>(n) : 0.0f;

    std::printf("normalization = %f\n", norm);

    CHECK(cudaStreamDestroy(stream));
    CHECK(cudaFree(deviceInput));
    CHECK(cudaFree(deviceOutput));

    return 0;
}

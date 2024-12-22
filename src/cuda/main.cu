#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <cuda_runtime.h>
#include "sys/time.h"

#define CHARSET "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
#define CHARSET_SIZE 62
#define THREADS_PER_BLOCK 256
#define batchSize 1000000000

#ifndef PASSWORD_LENGTH
#define PASSWORD_LENGTH 5
#endif

__device__ const uint32_t S[] = {
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
};

__device__ const uint32_t K[] = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
};

#define F(X, Y, Z) ((X & Y) | (~X & Z))
#define G(X, Y, Z) ((X & Z) | (Y & ~Z))
#define H(X, Y, Z) (X ^ Y ^ Z)
#define I(X, Y, Z) (Y ^ (X | ~Z))

struct MD5Context {
    uint64_t size;
    uint32_t buffer[4]; 
    uint8_t input[64];
    uint8_t digest[16];
};

__device__ uint32_t rotateLeft(uint32_t x, uint32_t n) {
    return (x << n) | (x >> (32 - n));
}

__device__ void md5InitDevice(MD5Context *ctx) {
    ctx->size = (uint64_t)0;
    ctx->buffer[0] = 0x67452301;
    ctx->buffer[1] = 0xefcdab89;
    ctx->buffer[2] = 0x98badcfe;
    ctx->buffer[3] = 0x10325476;
}

__device__ void md5StepDevice(uint32_t *buffer, uint32_t *input){
    uint32_t AA = buffer[0];
    uint32_t BB = buffer[1];
    uint32_t CC = buffer[2];
    uint32_t DD = buffer[3];

    uint32_t E;

    unsigned int j;

    for(unsigned int i = 0; i < 64; ++i){
        switch(i / 16){
            case 0:
                E = F(BB, CC, DD);
                j = i;
                break;
            case 1:
                E = G(BB, CC, DD);
                j = ((i * 5) + 1) % 16;
                break;
            case 2:
                E = H(BB, CC, DD);
                j = ((i * 3) + 5) % 16;
                break;
            default:
                E = I(BB, CC, DD);
                j = (i * 7) % 16;
                break;
        }

        uint32_t temp = DD;
        DD = CC;
        CC = BB;
        BB = BB + rotateLeft(AA + E + K[i] + input[j], S[i]);
        AA = temp;
    }

    buffer[0] += AA;
    buffer[1] += BB;
    buffer[2] += CC;
    buffer[3] += DD;
}

__device__ void md5UpdateDevice(MD5Context *ctx, uint8_t *input_buffer, size_t input_len){
    uint32_t input[16];
    unsigned int offset = ctx->size % 64;
    ctx->size += (uint64_t)input_len;

    // Copy each byte in input_buffer into the next space in our context input
    for(unsigned int i = 0; i < input_len; ++i){
        ctx->input[offset++] = (uint8_t)*(input_buffer + i);

        // If we've filled our context input, copy it into our local array input
        // then reset the offset to 0 and fill in a new buffer.
        // Every time we fill out a chunk, we run it through the algorithm
        // to enable some back and forth between cpu and i/o
        if(offset % 64 == 0){
            for(unsigned int j = 0; j < 16; ++j){
                // Convert to little-endian
                // The local variable `input` our 512-bit chunk separated into 32-bit words
                // we can use in calculations
                input[j] = (uint32_t)(ctx->input[(j * 4) + 3]) << 24 |
                           (uint32_t)(ctx->input[(j * 4) + 2]) << 16 |
                           (uint32_t)(ctx->input[(j * 4) + 1]) <<  8 |
                           (uint32_t)(ctx->input[(j * 4)]);
            }
            md5StepDevice(ctx->buffer, input);
            offset = 0;
        }
    }
}

__device__ void md5FinalizeDevice(MD5Context *ctx){
	uint8_t PADDING[64] = {0};
    PADDING[0] = 0x80;

    uint32_t input[16];
    unsigned int offset = ctx->size % 64;
    unsigned int padding_length = offset < 56 ? 56 - offset : (56 + 64) - offset;

    // Fill in the padding and undo the changes to size that resulted from the update
    md5UpdateDevice(ctx, PADDING, padding_length);
    ctx->size -= (uint64_t)padding_length;

    // Do a final update (internal to this function)
    // Last two 32-bit words are the two halves of the size (converted from bytes to bits)
    for(unsigned int j = 0; j < 14; ++j){
        input[j] = (uint32_t)(ctx->input[(j * 4) + 3]) << 24 |
                   (uint32_t)(ctx->input[(j * 4) + 2]) << 16 |
                   (uint32_t)(ctx->input[(j * 4) + 1]) <<  8 |
                   (uint32_t)(ctx->input[(j * 4)]);
    }
    input[14] = (uint32_t)(ctx->size * 8);
    input[15] = (uint32_t)((ctx->size * 8) >> 32);

    md5StepDevice(ctx->buffer, input);

    // Move the result into digest (convert from little-endian)
    for(unsigned int i = 0; i < 4; ++i){
        ctx->digest[(i * 4) + 0] = (uint8_t)((ctx->buffer[i] & 0x000000FF));
        ctx->digest[(i * 4) + 1] = (uint8_t)((ctx->buffer[i] & 0x0000FF00) >>  8);
        ctx->digest[(i * 4) + 2] = (uint8_t)((ctx->buffer[i] & 0x00FF0000) >> 16);
        ctx->digest[(i * 4) + 3] = (uint8_t)((ctx->buffer[i] & 0xFF000000) >> 24);
    }
}

__device__ void generatePassword(uint64_t idx, char *password, int length) {
    password[length] = '\0';
    for (int i = length - 1; i >= 0; --i) {
        password[i] = CHARSET[idx % CHARSET_SIZE];
        idx /= CHARSET_SIZE;
    }
}

__device__ bool stringCompare(const char *str1, const char *str2) {
    int i = 0;
    while (str1[i] != '\0' && str2[i] != '\0') {
        if (str1[i] != str2[i]) {
            return false;
        }
        i++;
    }
    return str1[i] == '\0' && str2[i] == '\0';
}

__global__ void md5BruteForceKernel(uint8_t *targetHash, uint64_t offset, uint64_t currentBatchSize, bool *d_foundFlag) {
    uint64_t idx = blockIdx.x * blockDim.x + threadIdx.x + offset;

    if (*d_foundFlag || idx >= currentBatchSize + offset) return;

    char candidate[PASSWORD_LENGTH + 1];

    generatePassword(idx, candidate, PASSWORD_LENGTH);

    MD5Context ctx;
    md5InitDevice(&ctx);
    md5UpdateDevice(&ctx, (uint8_t *)candidate, PASSWORD_LENGTH);
    md5FinalizeDevice(&ctx);

    bool match = true;
    for (int i = 0; i < 16; i++) {
        if (ctx.digest[i] != targetHash[i]) {
            match = false;
            break;
        }
    }

    if (match) {
        printf("\nPassword found: %s\n", candidate);
		*d_foundFlag = true;
    }
}

void printProgressBar(double progress) {
	int progressBarWidth = 50;
	printf("\r[");
    int pos = (int)(progress / 100.0 * progressBarWidth);
    for (int i = 0; i < progressBarWidth; i++) {
        if (i < pos)
            printf("=");
        else if (i == pos)
            printf(">");
        else
            printf(" ");
    }
    printf("] %.2f%%", progress);
    fflush(stdout);
}

void md5BruteForceCUDA(const char *targetHashHex) {
	// printf("targetHashHex: %s\n", targetHashHex);
    uint8_t targetHash[16];
    for (int i = 0; i < 16; i++) {
        sscanf(targetHashHex + 2 * i, "%2hhx", &targetHash[i]);
    }
	printf("\n");

	// Allocate memory of hash value
    uint8_t *d_targetHash;
    cudaMalloc(&d_targetHash, 16);
    cudaMemcpy(d_targetHash, targetHash, 16, cudaMemcpyHostToDevice);

	// Allocate memory of flag
	bool h_foundFlag = false; // host variable
    bool *d_foundFlag;        // device variable
	cudaMalloc(&d_foundFlag, sizeof(bool));
    cudaMemcpy(d_foundFlag, &h_foundFlag, sizeof(bool), cudaMemcpyHostToDevice);
	
	// Define and calculate all possible passwords
    uint64_t totalCombinations = pow(CHARSET_SIZE, PASSWORD_LENGTH);
	//totalCombinations = 300000;
    uint64_t remainingCombinations = totalCombinations;
    uint64_t currentOffset = 0;

	double progress = 0.0; // Progress Bar
	while (remainingCombinations > 0) {
        uint64_t currentBatch = (remainingCombinations > batchSize) ? batchSize : remainingCombinations;
        int blocks = (currentBatch + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

        //printf("Launching kernel with %d blocks, batch size: %lu, offset: %lu\n", blocks, currentBatch, currentOffset);

        md5BruteForceKernel<<<blocks, THREADS_PER_BLOCK>>>(d_targetHash, currentOffset, currentBatch, d_foundFlag);

        cudaDeviceSynchronize();
        cudaError_t err = cudaGetLastError();
        if (err != cudaSuccess) {
            printf("CUDA Error: %s\n", cudaGetErrorString(err));
            break;
        }

		// Check password is found
		cudaMemcpy(&h_foundFlag, d_foundFlag, sizeof(bool), cudaMemcpyDeviceToHost);
		if (h_foundFlag) {
            printf("Early termination: password found.\n");
            break;
        }

		// Update progress
		currentOffset += currentBatch;
		remainingCombinations -= currentBatch;
		progress = (double)currentOffset / totalCombinations * 100.0;
		printProgressBar(progress);
    }
    //cudaDeviceSynchronize();
    cudaFree(d_targetHash);
}

int main(int argc, char **argv) {
    if (argc != 2) {
        printf("Usage: %s <MD5 hash>\n", argv[0]);
        return 1;
    }

	struct timeval start, end;
    gettimeofday(&start, NULL);

    md5BruteForceCUDA(argv[1]);

    gettimeofday(&end, NULL);
    double elapsedTime = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1000000.0;
    printf("\nExecution Time: %f seconds\n", elapsedTime);

    return 0;
}


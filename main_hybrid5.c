#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>
#include <omp.h>

#include "md5.h"

#define BATCH_SIZE 8

char charset[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
int target_size = 5;

char* generate_string(int number) {
    char* result = (char*) malloc(target_size+1);
    result[target_size] = '\0';
    for(int i = 0;i<target_size;i++) {
        result[target_size-i-1] = charset[number % 62];
        number /= 62;
    }
    return result;
}

int main(int argc, char *argv[]) {
    if(argc != 2){
        printf("Usage: %s <hash>\n", argv[0]);
        return 1;
    }

    uint8_t target[16];
    for(int i = 0;i<16;i++) {
        sscanf(argv[1] + 2*i, "%2hhx", target + i);
    }

    struct timeval start, end;
    gettimeofday(&start, NULL);
    int total = 916132832; // 62^5
    
    int found = 0;

    omp_set_num_threads(32);
    #pragma omp parallel for schedule(dynamic, 1024) shared(found)
    for(int i = 0; i<total; i+=BATCH_SIZE) { // enumerate all possible strings
        if(found) continue;
        //-------------
        char* strings[BATCH_SIZE];
        uint8_t* results[BATCH_SIZE];
        uint8_t result_buffers[BATCH_SIZE][16];
        
        // 設置results指針陣列
        for(int j = 0; j < BATCH_SIZE; j++) {
            results[j] = result_buffers[j];
        }
        // 生成一批字串
        for(int j = 0; j < BATCH_SIZE; j++) {
            strings[j] = generate_string(i + j);
        }
    
        // 並行計算MD5
        md5String_SIMD(strings, results);
    
        // 檢查結果
        for(int j = 0; j < BATCH_SIZE; j++) {
            // printf("It is %s\n", strings[j]);
            if(!memcmp(results[j], target, 16)){
                #pragma omp critical
                {
                    found = 1;
                }
                printf("Found: %s\n", strings[j]);
            }
        }
        for(int j = 0; j < BATCH_SIZE; j++) {
            free(strings[j]);
        }
    }
    //-------------
    gettimeofday(&end, NULL);
    printf("Time: %f s\n", (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1000000.0);
}
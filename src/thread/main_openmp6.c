#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>
#include <pthread.h>
#include <omp.h>

#include "md5.h"

char charset[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
int target_size = 6;
uint8_t target[16];

char* generate_string(long long number) {
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
    
    for(int i = 0;i<16;i++) {
        sscanf(argv[1] + 2*i, "%2hhx", target + i);
    }

    struct timeval start, end;
    long long total = 56800235584; // 62^6
    gettimeofday(&start, NULL);
    // start of test
    int found = 0;

    omp_set_num_threads(32);
    #pragma omp parallel for schedule(dynamic, 1024) shared(found)
    for(long long i = 0;i<total;i++) { // enumerate all possible strings
        if(found) continue;
        char* str = generate_string(i);
        uint8_t result[16];
        md5String(str, result);
        if(!memcmp(result, target, 16)){
            #pragma omp critical
            {
                found = 1;
            }
            printf("Found: %s\n", str);
        }
        free(str);
    }
    
    // end of test
    gettimeofday(&end, NULL);
    printf("Time: %f s\n", (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1000000.0);
}

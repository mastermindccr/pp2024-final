#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>
#include <pthread.h>
#include <stdatomic.h>

#include "md5.h"

char charset[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
int target_size = 5;
const int thread_cnt = 4;
atomic_int found = 0;
uint8_t target[16];

typedef struct {
    int start;
    int end;
} Thread_arg;

char* generate_string(int number) {
    char* result = (char*) malloc(target_size+1);
    result[target_size] = '\0';
    for(int i = 0;i<target_size;i++) {
        result[target_size-i-1] = charset[number % 62];
        number /= 62;
    }
    return result;
}

void thread_func(void* arg) {
    Thread_arg* thread_arg = (Thread_arg*) arg;
    int start = thread_arg->start;
    int end = thread_arg->end;
    for(int i = start;i<end;i++) { // enumerate all possible strings
        if(atomic_load(&found)) break;
        char* str = generate_string(i);
        uint8_t result[16];
        md5String(str, result);
        if(!memcmp(result, target, 16)){
            atomic_store(&found, 1);
            printf("Found: %s\n", str);
            break;
        }
        free(str);
    }
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
    int total = 916132832; // 62^5
    gettimeofday(&start, NULL);
    // start of test

    pthread_t threads[thread_cnt];
    Thread_arg thread_args[thread_cnt];

    for(int i = 0;i<thread_cnt;i++) {
        thread_args[i].start = total/thread_cnt*i;
        thread_args[i].end = total/thread_cnt*(i+1);
        pthread_create(&threads[i], NULL, (void*)thread_func, &thread_args[i]);
    }

    for(int i = 0;i<thread_cnt;i++) {
        pthread_join(threads[i], NULL);
    }
    
    // end of test
    gettimeofday(&end, NULL);
    printf("Time: %f s\n", (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1000000.0);
}

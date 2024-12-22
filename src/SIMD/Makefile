CC = gcc
CFLAGS = -Ofast -mavx2 -march=native

all: SIMD5 SIMD6
SIMD5: md5.c main_SIMD5.c
	@$(CC) $(CFLAGS) -o main_SIMD5 md5.c main_SIMD5.c

SIMD6: md5.c main_SIMD6.c
	@$(CC) $(CFLAGS) -o main_SIMD6 md5.c main_SIMD6.c

clean:
	@$(RM) main_SIMD5 main_SIMD6

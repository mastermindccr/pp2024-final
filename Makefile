CC = gcc

CFLAGS = -Ofast -mavx2 -march=native

hybrid5: md5.c main_hybrid5.c
	@$(CC) $(CFLAGS) -lpthread -fopenmp -o md5_hybrid5 md5.c main_hybrid5.c

hybrid6: md5.c main_hybrid6.c
	@$(CC) $(CFLAGS) -lpthread -fopenmp -o md5_hybrid6 md5.c main_hybrid6.c

thread5: md5.c main_thread5.c
	@$(CC) $(CFLAGS) -lpthread -o md5_thread5 md5.c main_thread5.c

thread6: md5.c main_thread6.c
	@$(CC) $(CFLAGS) -lpthread -o md5_thread6 md5.c main_thread6.c

openmp5: md5.c main_openmp5.c
	@$(CC) $(CFLAGS) -fopenmp -o md5_openmp5 md5.c main_openmp5.c

openmp6: md5.c main_openmp6.c
	@$(CC) $(CFLAGS) -fopenmp -o md5_openmp6 md5.c main_openmp6.c

thread_report:
	perf record -e cpu-clock --call-graph fp ./md5_thread 44a2b258d962b934c9f4d54b4460160d
	perf report

openmp_report:
	perf record -e cpu-clock --call-graph fp ./md5_openmp 44a2b258d962b934c9f4d54b4460160d
	perf report

clean:
	@$(RM) md5_thread md5_openmp

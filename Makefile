CC = gcc

CFLAGS = -Ofast

thread: md5.c main_thread.c
	@$(CC) $(CFLAGS) -lpthread -o md5_thread md5.c main_thread.c

openmp: md5.c main_openmp.c
	@$(CC) $(CFLAGS) -fopenmp -o md5_openmp md5.c main_openmp.c

thread_report:
	perf record -e cpu-clock --call-graph fp ./md5_thread 44a2b258d962b934c9f4d54b4460160d
	perf report

openmp_report:
	perf record -e cpu-clock --call-graph fp ./md5_openmp 44a2b258d962b934c9f4d54b4460160d
	perf report

clean:
	@$(RM) md5

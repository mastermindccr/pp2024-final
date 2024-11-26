CC = gcc
CFLAGS = -O3 -mavx2 -march=native
SOURCES = main.c md5.c
TARGET = main.out

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) $(SOURCES) -o $(TARGET)

clean:
	rm -f $(TARGET)

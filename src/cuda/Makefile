# Compiler
NVCC = nvcc

# Target executable
TARGET = crack_md5

# Default PASSWORD_LENGTH
PASSWORD_LENGTH ?= 5

# Source files
SRC = main.cu

# Temp file to track PASSWORD_LENGTH
DEFINES_FILE = .defines

# Build rule
all: $(TARGET)

# Target depends on source and defines file
$(TARGET): $(SRC) $(DEFINES_FILE)
	$(NVCC) -DPASSWORD_LENGTH=$(PASSWORD_LENGTH) -o $@ $<

# Track PASSWORD_LENGTH changes
$(DEFINES_FILE):
	echo "PASSWORD_LENGTH=$(PASSWORD_LENGTH)" > $@

.PHONY: check_defines
check_defines:
	@if [ -f $(DEFINES_FILE) ]; then \
		if ! grep -q "PASSWORD_LENGTH=$(PASSWORD_LENGTH)" $(DEFINES_FILE); then \
			echo "PASSWORD_LENGTH changed, forcing recompilation."; \
			rm -f $(TARGET) $(DEFINES_FILE); \
		fi \
	fi

# Ensure check_defines is run before build
$(TARGET): check_defines

# Clean rule
clean:
	rm -f $(TARGET) $(DEFINES_FILE)


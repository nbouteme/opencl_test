NAME = rtv1
TYPE = prog

MODULES = src cl
CFLAGS = -Wall -Wextra -Werror -g
#CFLAGS = -Wall -Wextra -Werror -flto -Ofast -march=native -mtune=native -ffinite-math-only -funsafe-math-optimizations -fno-math-errno  -ffast-math
LFLAGS = $(CFLAGS) -lm
LFLAGS_Darwin = -framework Opencl
LFLAGS_Linux = -lOpenCL
INCLUDE_DIRS = $(PKG_DIR)/include
DEPS = libft xmlx

OUTPUT = $(NAME)

ifneq ($(filter mcpu,$(MODULES)),)
LFLAGS += -lpthread
endif

ifneq ($(filter cl,$(MODULES)),)


ifneq (($shell uname),Darwin)
cl_CC = /System/Library/Frameworks/OpenCL.framework/Libraries/openclc
cl_CFLAGS = -emit-llvm  -arch gpu_64 $(addprefix -I,$(INCLUDE_DIRS_ACC))
OBJCOPY = gobjcopy
OUTPUT_FORMAT = mach-o-x86-64
else
cl_CC = clcc
OBJCOPY = objcopy
# a determiner
cl_CFLAGS = -emit-llvm  -arch gpu_64 $(addprefix -I,$(INCLUDE_DIRS_ACC))
OUTPUT_FORMAT = x86_64
endif
cl_EXT := .cl

OBJS += cl_source.o

define BUILD_RULE_cl
# en plus de compiler, on genere un fichier objet ELF qui contient le binaires et des symboles
# qui le definisse (debut et taille)

build/cl_source.o:
	@echo bits 64 > .tmp2.s
	@echo section .rodata >> .tmp2.s
	@for i in $$($1_OBJSP); do \
		echo extern _start_$$$$i | tr /.- ___ >> .tmp2.s;\
		echo extern _size_$$$$i | tr /.- ___ >> .tmp2.s;\
	done
	@echo global _symtable >> .tmp2.s
	@for i in $$($1_OBJSP); do \
		echo _str_$$$$i: | tr /.- ___ >> .tmp2.s;\
		echo db \'str_$$$$i\', 0 | tr /.- ___ >> .tmp2.s;\
	done
	@echo _symtable: >> .tmp2.s
	@for i in $$($1_OBJSP); do \
		echo dq _str_$$$$i | tr /.- ___ >> .tmp2.s;\
		echo dq _start_$$$$i | tr /.- ___ >> .tmp2.s;\
		echo dq _size_$$$$i | tr /.- ___ >> .tmp2.s;\
		echo dq 0 >> .tmp2.s;\
	done
	@echo dq 0 >> .tmp2.s
	@echo dq 0 >> .tmp2.s
	@echo dq 0 >> .tmp2.s
	@echo dq 0 >> .tmp2.s
	@nasm -fmacho64 .tmp2.s -o $$@
	@rm .tmp2.s

build/$1/%.o: $1/%$$($1_EXT) build
	$$(gen-pb $$<)
	$$($1_CC) $$($1_CFLAGS) $(ACFLAGS_ACC) $$(S_CFLAGS_ACC) -c $$< -o $$@ $$(SFLAGS_ACC)
	@mv $$@ $$@.bin
	@echo bits 64					>  .tmp.s
	@echo section .rodata			>> .tmp.s
	@echo -n global _start_			>> .tmp.s
	@echo $$@ | tr /.- ___			>> .tmp.s
	@echo -n global _end_			>> .tmp.s
	@echo $$@ | tr /.- ___			>> .tmp.s
	@echo -n global _size_			>> .tmp.s
	@echo $$@ | tr /.- ___			>> .tmp.s
	@echo -n _start_				>> .tmp.s
	@echo -n $$@ | tr /.- ___		>> .tmp.s
	@echo :   incbin \"$$@.bin\"	>> .tmp.s
	@echo -n _end_					>> .tmp.s
	@echo -n $$@ | tr /.- ___		>> .tmp.s
	@echo :							>> .tmp.s
	@echo -n _size_					>> .tmp.s
	@echo -n $$@ | tr /.- ___		>> .tmp.s
	@echo -n :    dd $$$$\-_start_	>> .tmp.s
	@echo -n $$@ | tr /.- ___		>> .tmp.s
	@nasm -fmacho64 .tmp.s -o $$@
	@rm .tmp.s

endef

endif

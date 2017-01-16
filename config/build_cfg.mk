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
cl_EMBED = yes

define BUILD_RULE_cl
# en plus de compiler, on genere un fichier objet ELF qui contient le binaires et des symboles
# qui le definisse (debut et taille)

build/$1/%.o: $1/%$$($1_EXT) build
	$$(gen-pb $$<)
	@$$($1_CC) $$($1_CFLAGS) $(ACFLAGS_ACC) $$(S_CFLAGS_ACC) -c $$< -o $$@ $$(SFLAGS_ACC)
	@mv $$@ $$@.bin
	@nasm -fmacho64 .res_template.s -dNAME=`echo $$@ | tr /.- ___` -dPATH=$$@.bin -o $$@

endef

endif

CURDIR := $(shell pwd)
ifeq ($(RUNDIR),)
	RUNDIR := $(CURDIR)
else
	SUBFOLDERS += $(shell find $(RUNDIR) -maxdepth 1 -type d ! -path $(RUNDIR) ! -path $(RUNDIR)/config | grep -v '/\.')
endif

file_exist = $(shell test -e $1 && echo "exist")

$(if $(call file_exist,$(RUNDIR)/config/ext_make.so),\
	$(eval load $(RUNDIR)/config/ext_make.so(setup)), \
	$(eval $(warning\
Could not find make extension. \
Falling back to silent mode, expect missing features.)))

SHELL = /bin/bash
SYSTEM = $(shell uname)
TERM_WIDTH := $(get-term-info WIDTH)

define redout
$(shell printf "\033[0;31m%s\033[0m" "$(strip $1)")
endef

define blueout
$(shell printf "\033[0;34m%s\033[0m" "$(strip $1)")
endef

define greenout
$(shell printf "\033[0;32m%s\033[0m" "$(strip $1)")
endef

src_from_modules = $(shell find $1 -maxdepth 1 -type f -or -type l | grep -v '^/\.' | grep '$($1_EXT)$$')
nsrc_from_modules = $(shell find $1 -maxdepth 1 -type f -or -type l | grep -v '^/\.' | grep '.c$$' | wc -l)
eq = $(and $(findstring $(1),$(2)),$(findstring $(2),$(1)))
get_val_in_file =	$(if $(call file_exist,$1),\
						$(shell cat $1  | sed -n "s/$2.=.//p"))

BUILD_CFG := $(shell ls ./config/build_cfg.mk 2> /dev/null)
LINK_CFG := $(shell ls ./config/link_cfg.mk 2> /dev/null)
SUBFOLDERS := $(shell find `pwd` -maxdepth 1 -type d ! -path `pwd` ! -path `pwd`/config ! -path `pwd`/build  | grep -v '/\.')

PKG_DIR = $(shell pwd)

$(assert-error LINK_CFG,BUILD_CFG)
include $(BUILD_CFG)
$(assert-error NAME,OUTPUT,MODULES,TYPE)

CUR_NAME			:= $(NAME)
CUR_INCLUDE_DIRS	:= $(INCLUDE_DIRS)
CUR_OPTS			:= $(OPTS)
CUR_TYPE			:= $(TYPE)
CUR_DEPS			:= $(DEPS)
CUR_OUTPUT			:= $(OUTPUT)
CUR_MODULES			:= $(shell find $(MODULES) -mindepth 0 -type d)

$(foreach sub,$(CUR_MODULES),							\
	$(eval PARENT := $(dir $(sub)))						\
	$(eval PARENT := $(PARENT:/=))						\
	$(if $(call eq $(PARENT),.),kek,					\
		$(eval $(if $($(PARENT)_CC), $(sub)_CC ?= $($(PARENT)_CC)))			\
		$(eval $(if $($(PARENT)_CFLAGS), $(sub)_CFLAGS ?= $($(PARENT)_CFLAGS)))	\
		$(eval $(if $($(PARENT)_EXT), $(sub)_EXT ?= $($(PARENT)_EXT)))			\
		$(eval BUILD_RULE_$(sub) = $(BUILD_RULE_$(PARENT)))\
))

KEK = cl/kek

$(info ==== $(BUILD_RULE_$(KEK)) ====)

LFLAGS_ACC			:= $(LFLAGS)
INCLUDE_DIRS_ACC	:= $(INCLUDE_DIRS)
CFLAGS_ACC			:= $(addprefix -I,$(INCLUDE_DIRS)) $(CFLAGS)
S_LFLAGS_ACC		:= $(LFLAGS_$(SYSTEM))
S_CFLAGS_ACC		:= $(CFLAGS_$(SYSTEM))
S_FLAGS_ACC			:= $(SFLAGS_$(SYSTEM))

all: $(CUR_OUTPUT)

.SUFFIXES:

define GEN_DEP_RULE
$1:
	make -C $2 RUNDIR=$(RUNDIR)
endef

$(foreach dep,$(CUR_DEPS),																					\
	$(foreach dir,$(SUBFOLDERS),																			\
		$(eval CURNAME:=$(call get_val_in_file,$(dir)/config/build_cfg.mk,NAME))							\
		$(if $(call file_exist,$(dir)/config/build_cfg.mk),													\
			$(eval																							\
				CURNAME=$(call get_val_in_file,$(dir)/config/build_cfg.mk,NAME)								\
				$(if $(call eq,$(CURNAME),$(dep)),															\
					$(if $(shell make -q -C $(dir) RUNDIR=$(RUNDIR) &> /dev/null || echo "not_updat_ed"),	\
						$(shello make --no-print-directory -C $(dir) RUNDIR=$(RUNDIR)))						\
					$(eval $(dep)_FOUND=true)																\
					$(eval PKG_DIR=$(dir))																	\
					$(eval include $(dir)/config/link_cfg.mk)												\
					$(eval LFLAGS_ACC += $(LFLAGS))															\
					$(eval CFLAGS_ACC += $(CFLAGS))															\
					$(eval INCLUDE_DIRS_ACC += $(INCLUDE_DIRS))												\
					$(eval SFLAGS_ACC += $(SFLAGS_$(SYSTEM)))												\
					$(eval S_LFLAGS_ACC += $(LFLAGS_$(SYSTEM)))												\
					$(eval S_CFLAGS_ACC += $(CFLAGS_$(SYSTEM)))												\
					$(eval include $(dir)/config/build_cfg.mk)												\
					$(eval DEP_ACC += $(OUTPUT))															\
					$(eval $(call GEN_DEP_RULE,$(OUTPUT),$(dir))))											\
			)																								\
		)																									\
	)																										\
	$(if $($(dep)_FOUND),,$(error Dependency $(dep) not found.))											\
)

BUILD_DEPS	 = build

build:
	$(info $(call blueout,Building temporary build directory hierachy...))
	@mkdir -p build

define BUILD_DIR_RULE

$$(eval $1_CC ?= $(CC))
$$(eval $1_EXT ?= .c)

$$(eval TMP = $$(call src_from_modules,$1))
$$(eval SRCS += $$(TMP))
$$(eval $1_OBJS = $$(TMP:$$($1_EXT)=.o))
$$(eval $1_OBJSP = $$(addprefix build/,$$($1_OBJS)))
$$(eval OBJS += $$($1_OBJS))

$(eval $(if $($1_CFLAGS),\
	$(eval ACFLAGS_ACC = ),\
	$(eval ACFLAGS_ACC = $(CFLAGS_ACC))))

build/$1: build
	@mkdir -p build/$1

ifneq ($$($1_EMBED),)

$$(eval OBJS += $1/$1_embedded.o)

build/$1/$1_embedded.o: $(addprefix build/,$(OBJS))
	@echo bits 64 > .tmp2.s
	@echo section .rodata >> .tmp2.s
	@for i in $$($1_OBJSP); do \
		echo extern _start_$$$$i | tr /.- ___ >> .tmp2.s;\
		echo extern _size_$$$$i | tr /.- ___ >> .tmp2.s;\
	done
	@echo -n global >> .tmp2.s
	@echo _$1_symtable: | tr /.- ___ >> .tmp2.s;
	@for i in $$($1_OBJSP); do \
		echo _str_$$$$i: | tr /.- ___ >> .tmp2.s;\
		echo db \'str_$$$$i\', 0 | tr /.- ___ >> .tmp2.s;\
	done
	@echo _$1_symtable: >> .tmp2.s
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

endif

endef

define BUILD_RULE_DEFAULT
build/$1/%.o: $1/%$$($1_EXT) build
	$$(gen-pb $$<)
	$$($1_CC) $$($1_CFLAGS) $(ACFLAGS_ACC) $$(S_CFLAGS_ACC) -c $$< -o $$@ $$(SFLAGS_ACC)
endef

to_def = $(shell echo $1 | tr [:lower:]/.- [:upper:]___)

$(foreach mod,$(CUR_MODULES),						\
	$(eval SFLAGS_ACC += -D$(call to_def,$(mod)))	\
	$(eval BUILD_DEPS += build/$(mod))				\
	$(eval $(call BUILD_DIR_RULE,$(mod)))			\
	$(eval $(if $(BUILD_RULE_$(mod)),				\
		$(call BUILD_RULE_$(mod),$(mod)),			\
		$(info $(mod) DOESNT HAVE SPECIFIC RULE)$(call BUILD_RULE_DEFAULT,$(mod))))			\
)

#$(info $(.VARIABLES))

NSRCS = $(words $(SRCS))

$(init-pb $(NSRCS),$(TERM_WIDTH))
$(print-head $(CUR_OUTPUT),$(TERM_WIDTH))

tail:
	$(print-tail $(TERM_WIDTH))

$(CUR_OUTPUT): $(BUILD_DEPS) $(DEP_ACC) $(addprefix build/,$(OBJS)) | tail
	@printf "\e[34mLinking %s..." $(CUR_OUTPUT)
ifeq ($(CUR_TYPE),prog)
	$(CC) $(addprefix build/,$(OBJS)) -o $(CUR_OUTPUT) $(LFLAGS_ACC) $(S_LFLAGS_ACC) $(SFLAGS_ACC)
else
	@ld -x -r $(addprefix build/,$(OBJS)) -o $(OUTPUT)
endif
	@printf "\e[32m✓\e[0m\n"

.PHONY: clean fclean re all inc

clean: | tail
	@/bin/rm -rf $(addprefix build/,$(OBJS))

fclean: clean | tail
	@/bin/rm -rf $(CUR_OUTPUT) build

inc: | tail
	$(info $(INCLUDE_DIRS_ACC))

re: fclean all

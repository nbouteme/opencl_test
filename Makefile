# Toi qui t'aventure sur ces terres
# Passe ton chemin. Ou abondonne tout espoir.
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
# C'est mon dernier avertissement, continue a tes risques et perils.
src_from_modules = $(shell find $1 -maxdepth 1 -type f -or -type l | grep -v '^/\.' | grep '$($1_EXT)$$')
nsrc_from_modules = $(shell find $1 -maxdepth 1 -type f -or -type l | grep -v '^/\.' | grep '.c$$' | wc -l)
eq = $(and $(findstring $1,$2),$(findstring $2,$1))
get_val_in_file =	$(if $(call file_exist,$1),\
						$(shell cat $1  | sed -n "s/$2.=.//p"))

BUILD_CFG := $(shell ls ./config/build_cfg.mk 2> /dev/null)
LINK_CFG := $(shell ls ./config/link_cfg.mk 2> /dev/null)
SUBFOLDERS := $(shell find `pwd` -maxdepth 1 -type d ! -path `pwd` ! -path `pwd`/config ! -path `pwd`/build  | grep -v '/\.')

to_def = $(shell echo $1 | tr [:lower:]/.- [:upper:]___)
to_esc = $(shell echo $1 | tr /.- ___)

PKG_DIR = $(shell pwd)

$(assert-error LINK_CFG,BUILD_CFG)
include $(BUILD_CFG)
$(assert-error NAME,OUTPUT,MODULES,TYPE)
# Wanna have a bad time?
CUR_NAME			:= $(NAME)
CUR_INCLUDE_DIRS	:= $(INCLUDE_DIRS)
CUR_OPTS			:= $(OPTS)
CUR_TYPE			:= $(TYPE)
CUR_DEPS			:= $(DEPS)
CUR_OUTPUT			:= $(OUTPUT)
CUR_MODULES			:= $(shell find $(MODULES) -mindepth 0 -type d)

KEK = cl/kek

define def_cpy
define $1
$2
endef
endef

$(foreach sub,$(CUR_MODULES),													\
	$(eval PARENT := $(dir $(sub)))												\
	$(eval PARENT := $(PARENT:/=))												\
	$(if $(call eq,$(PARENT),.),,												\
		$(if $($(PARENT)_CC), $(eval $(sub)_CC ?= $($(PARENT)_CC)))				\
		$(if $($(PARENT)_CFLAGS), $(eval $(sub)_CFLAGS ?= $($(PARENT)_CFLAGS)))	\
		$(if $($(PARENT)_EXT), $(eval $(sub)_EXT ?= $($(PARENT)_EXT)))			\
		$(if $($(PARENT)_EMBED), $(eval $(sub)_EMBED ?= $($(PARENT)_EMBED)))	\
		$(if $(BUILD_RULE_$(PARENT)),											\
			$(if $(BUILD_RULE_$(sub)),,											\
				$(eval $(call def_cpy,BUILD_RULE_$(sub),$(BUILD_RULE_$(PARENT))))\
			)																	\
		)																		\
	)																			\
)

LFLAGS_ACC			:= $(LFLAGS)
INCLUDE_DIRS_ACC	:= $(INCLUDE_DIRS)
CFLAGS_ACC			:= $(addprefix -I,$(INCLUDE_DIRS)) $(CFLAGS)
S_LFLAGS_ACC		:= $(LFLAGS_$(SYSTEM))
S_CFLAGS_ACC		:= $(CFLAGS_$(SYSTEM))
S_FLAGS_ACC			:= $(SFLAGS_$(SYSTEM))

#####################
#### Watch THIS! ####
#####################

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

# pssssht.... nothing personal......,, kid

define BUILD_DIR_RULE

$$(eval $1_CC ?= $(CC))
$$(eval $1_EXT ?= .c)
$$(eval MY_NAME = $1)

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

$(if $(call file_exist,./.table_template.s),,$(error Missing table template, required for embedding ressources))
$$(eval $1_OUTPUT_EOBJ = $$(call to_esc,$1))
$$(eval OBJS += $1/$$($1_OUTPUT_EOBJ)_embedded.o)

build/$1/$$($1_OUTPUT_EOBJ)_embedded.o: $(addprefix build/,$(OBJS))
	nasm -fmacho64 .table_template.s -dEPATH=$$($1_OUTPUT_EOBJ) -dOBJECTS=`echo $$($1_OBJSP) | tr ' /.-' ',___'` -o $$@

endif

endef

define BUILD_RULE_DEFAULT
build/$1/%.o: $1/%$$($1_EXT) build
	$$(gen-pb $$<)
	@$$($1_CC) $$($1_CFLAGS) $(ACFLAGS_ACC) $$(S_CFLAGS_ACC) -c $$< -o $$@ $$(SFLAGS_ACC)
endef

$(foreach mod,$(CUR_MODULES),						\
	$(eval SFLAGS_ACC += -D$(call to_def,$(mod)))	\
	$(eval BUILD_DEPS += build/$(mod))				\
	$(eval $(call BUILD_DIR_RULE,$(mod)))			\
	$(eval $(if $(BUILD_RULE_$(mod)),				\
		$(call BUILD_RULE_$(mod),$(mod)),			\
		$(call BUILD_RULE_DEFAULT,$(mod))))			\
	$(if $($(mod)_EMBED),$(eval EMBED_MODS += $(mod)))\
)

define EMBED_PATH_RULE
$$(eval OBJS += embedded_mods.o)

build/embedded_mods.o: $(addprefix build/,$(OBJS))
	nasm -fmacho64 .embed_template.s -dOBJECTS=`echo $$(EMBED_MODS) | tr ' /.-' ',___'` -o $$@
endef

$(if $(EMBED_MODS), $(eval $(EMBED_PATH_RULE)))

NSRCS = $(words $(SRCS))

$(init-pb $(NSRCS),$(TERM_WIDTH))
$(print-head $(CUR_OUTPUT),$(TERM_WIDTH))

tail:
	$(print-tail $(TERM_WIDTH))

$(CUR_OUTPUT): $(BUILD_DEPS) $(DEP_ACC) $(addprefix build/,$(OBJS)) | tail
	@printf "\e[34mLinking %s..." $(CUR_OUTPUT)
ifeq ($(CUR_TYPE),prog)
	@$(CC) $(addprefix build/,$(OBJS)) -o $(CUR_OUTPUT) $(LFLAGS_ACC) $(S_LFLAGS_ACC) $(SFLAGS_ACC)
else
	@ld -r $(addprefix build/,$(OBJS)) -o $(OUTPUT)
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

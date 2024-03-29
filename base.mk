## base.mk: b6ea33b+, see https://github.com/jmesmon/trifles.git
# Usage:
#
# == Targets ==
# 'all'
# $(TARGETS)
# show-cflags		Set the var FILE=some-c-file.c to see cflags for a
#                       particular file
# show-targets
# install
# clean
# TARGET.clean
# TARGET.install
#
# == For use by the one who runs 'make' (or in some cases the Makefile) ==
# $(O)		    set to a directory to write build output to that directory
# $(V)              when defined, prints the commands that are run.
# $(CFLAGS)         expected to be overridden by the user or build system.
# $(LDFLAGS)        same as CFLAGS, except for LD.
# $(ASFLAGS)
# $(CXXFLAGS)
# $(CPPFLAGS)
#
# $(CROSS_COMPILE)  a prefix on $(CC) and other tools.
#                   "CROSS_COMPILE=arm-linux-" (note the trailing '-')
# $(CC)
# $(CXX)
# $(LD)
# $(AS)
# $(FLEX)
# $(BISON)
#
# == Required in the makefile ==
# all::		    place this target at the top.
# $(obj-sometarget) the list of objects (generated by CC) that make up a target
#                   (in the list TARGET).
# $(TARGETS)        a list of binaries (the output of LD).
#
# == Optional (for use in the makefile) ==
# $(NO_INSTALL)     when defined, no install target is emitted.
# $(ALL_CFLAGS)     non-overriden flags. Append (+=) things that are absolutely
#                   required for the build to work into this.
# $(ALL_LDFLAGS)    same as ALL_CFLAGS, except for LD.
#		    example for adding some library:
#
#			sometarget: ALL_LDFLAGS += -lrt
#
#		    Note that in some cases (none I can point out, I just find
#		    this shifty) this usage could have unintended consequences
#		    (such as some of the ldflags being passed to other link
#		    commands). The use of $(ldflags-sometarget) is recommended
#		    instead.
#
# $(ALL_CPPFLAGS)
#
# $(ldflags-some-target)
#
# $(cflags-some-object-without-suffix)
# $(cflags-some-target)
# $(cxxflags-some-object-without-suffix)
# $(cxxflags-some-target)
#
# OBJ_TRASH		$(1) expands to the object. Expanded for every object.
# TARGET_TRASH		$* expands to the target. Expanded for every target.
# TRASH
# BIN_EXT		Add an extention to each binary produced (.elf, .exe)
#
# == How to use with FLEX + BISON support ==
#
# obj-foo = name.tab.o name.ll.o
# name.ll.o : name.tab.h
# TRASH += name.ll.c name.tab.c name.tab.h
# # Optionally
# PP_name = not_quite_name_
#

# TODO:
# - install disable per target.
# - flag tracking per target.'.obj.o.cmd'
# - profile guided optimization support.
# - build with different flags placed into different output directories.
# - library building (shared & static)
# - per-target CFLAGS (didn't I hack this in already?)
# - will TARGETS always be outputs from Linking?
# - continous build mechanism ('watch' is broken)
# - handle the mess that is linking for C++ vs C vs ld -r
# - CCLD vs LD and LDFLAGS
# - per target CCLD/LD
# - check if certain code builds
# - check if certain flags work
# - check if certain headers/libs are installed
# - use the above 3 to conditionally enable certain targets

# Delete the default suffixes
.SUFFIXES:

O = .
BIN_TARGETS=$(addprefix $(O)/,$(addsuffix $(BIN_EXT),$(TARGETS)))

.PHONY: all FORCE
all:: $(BIN_TARGETS)

ifdef WANT_VERSION
VERSION := $(shell $(HOME)/trifles/setlocalversion)
VERSION_FLAGS = -DVERSION=$(VERSION)
ifeq ($(WANT_VERSION),global)
ALL_CPPFLAGS += $(VERSION_FLAGS)
endif
endif

# Prioritize environment specified variables over our defaults
var-def = $(if $(findstring $(origin $(1)),default undefined),$(eval $(1) = $(2)))

# overriding these in a Makefile while still allowing the user to
# override them is tricky.
$(call var-def,CC,$(CROSS_COMPILE)gcc)
$(call var-def,CXX,$(CROSS_COMPILE)g++)
$(call var-def,CCLD,$(CC))
$(call var-def,LD,ld)
$(call var-def,AS,$(CC))
$(call var-def,RM,rm -f)
$(call var-def,FLEX,flex)
$(call var-def,BISON,bison)

show-cc:
	@echo $(CC)

ifdef DEBUG
OPT=-O0
else
OPT=-Os
endif

DBG_FLAGS = -ggdb3 -gdwarf-4 -fvar-tracking-assignments
ifndef NO_SANITIZE
DBG_FLAGS += -fsanitize=address
endif

CC_TYPE ?= gcc

ifndef NO_LTO
# TODO: use -flto=jobserver
ifeq ($(CC_TYPE),gcc)
CFLAGS  ?= -flto $(DBG_FLAGS)
LDFLAGS ?= $(ALL_CFLAGS) $(OPT) -fuse-linker-plugin
else ifeq ($(CC_TYPE),clang)
LDFLAGS ?= $(OPT)
CFLAGS  ?= -emit-llvm $(DBG_FLAGS)
endif
else
CFLAGS  ?= $(OPT) $(DBG_FLAGS)
endif

# c/c+++ shared flags
COMMON_CFLAGS += -Wall
COMMON_CFLAGS += -Wundef -Wshadow
COMMON_CFLAGS += -pipe
COMMON_CFLAGS += -Wcast-align
COMMON_CFLAGS += -Wwrite-strings

# C only flags that just turn on some warnings
C_CFLAGS = $(COMMON_CFLAGS)
C_CFLAGS += -Wstrict-prototypes
C_CFLAGS += -Wmissing-prototypes
C_CFLAGS += -Wold-style-definition
C_CFLAGS += -Wmissing-declarations
C_CFLAGS += -Wundef
C_CFLAGS += -Wbad-function-cast

# -Wpointer-arith		I like pointer arithmetic
# -Wnormalized=id		not supported by clang
# -Wunsafe-loop-optimizations	not supported by clang

ALL_CFLAGS += -std=gnu99

ALL_CPPFLAGS += $(CPPFLAGS)

ALL_CFLAGS   += $(ALL_CPPFLAGS) $(C_CFLAGS) $(CFLAGS)
ALL_CXXFLAGS += $(ALL_CPPFLAGS) $(COMMON_CFLAGS) $(CXXFLAGS)

ifndef NO_BUILD_ID
LDFLAGS += -Wl,--build-id
else
LDFLAGS += -Wl,--build-id=none
endif

ifndef NO_AS_NEEDED
LDFLAGS += -Wl,--as-needed
else
LDFLAGS += -Wl,--no-as-needed
endif

ALL_LDFLAGS += $(LDFLAGS)
ALL_ASFLAGS += $(ASFLAGS)

# FIXME: need to exclude '-I', '-l', '-L' options
# - potentially seperate those flags from ALL_*?
MAKE_ENV = CC="$(CC)" CCLD="$(CCLD)" AS="$(AS)" CXX="$(CXX)"
         # CFLAGS="$(ALL_CFLAGS)" \
	   LDFLAGS="$(ALL_LDFLAGS)" \
	   CXXFLAGS="$(ALL_CXXFLAGS)" \
	   ASFLAGS="$(ALL_ASFLAGS)"

ifndef V
	QUIET_CC    = @ echo '  CC   ' $@;
	QUIET_CXX   = @ echo '  CXX  ' $@;
	QUIET_LINK  = @ echo '  LINK ' $@;
	QUIET_LSS   = @ echo '  LSS  ' $@;
	QUIET_SYM   = @ echo '  SYM  ' $@;
	QUIET_FLEX  = @ echo '  FLEX ' $@;
	QUIET_BISON = @ echo '  BISON' $*.tab.c $*.tab.h;
	QUIET_AS    = @ echo '  AS   ' $@;
	QUIET_SUBMAKE  = @ echo '  MAKE ' $@;
	QUIET_AR    = @ echo '  AR   ' $@;
endif

define sub-make-no-clean
$1 : FORCE
	$$(QUIET_SUBMAKE)$$(MAKE) $$(MAKE_ENV) $$(MFLAGS) --no-print-directory $3 -C $$(dir $$@) $$(notdir $$@)
endef

define sub-make-clean
$(eval $(call sub-make-no-clean,$(1),$(2)))
.PHONY: $(1)
clean: $(1)
endef

define sub-make
$(eval $(call sub-make-no-clean,$(1),$(2)))
$(eval $(call sub-make-clean,$(dir $(1))/clean,$(2)))
endef

# Avoid deleting .o files
.SECONDARY:

obj-to-dep = $(foreach obj,$(1),$(dir $(obj)).$(notdir $(obj)).d)
target-dep = $(addprefix $(O)/,$(call obj-to-dep,$(obj-$(1))))
target-obj = $(addprefix $(O)/,$(obj-$(1)))

# flags-template flag-prefix vars message
# Defines a target '.TRACK-$(flag-prefix)FLAGS'.
# if $(ALL_$(flag-prefix)FLAGS) or $(var) changes, any rules depending on this
# target are rebuilt.
define flags-template
TRACK_$(1)FLAGS = $(foreach var,$(2),$$($(var))):$$(subst ','\'',$$(ALL_$(1)FLAGS))
$(O)/.TRACK-$(1)FLAGS: FORCE
	@FLAGS='$$(TRACK_$(1)FLAGS)'; \
	if test x"$$$$FLAGS" != x"`cat $(O)/.TRACK-$(1)FLAGS 2>/dev/null`" ; then \
		echo 1>&2 "    * new $(3)"; \
		echo "$$$$FLAGS" >$(O)/.TRACK-$(1)FLAGS; \
	fi
TRASH += $(O)/.TRACK-$(1)FLAGS
endef

$(eval $(call flags-template,AS,AS,assembler build flags))
$(eval $(call flags-template,C,CC,c build flags))
$(eval $(call flags-template,CXX,CXX,c++ build flags))
$(eval $(call flags-template,LD,LD,link flags))

parser-prefix = $(if $(PP_$*),$(PP_$*),$*_)

dep-gen = -MMD -MF $(call obj-to-dep,$@)

define build-link-flags
$(foreach obj,$(obj-$(1)),$(eval cflags-$(obj:.o=) += $(cflags-$(1))))
$(foreach obj,$(obj-$(1)),$(eval cxxflags-$(obj:.o=) += $(cxxflags-$(1))))
endef

define BIN-LINK
$(eval $(call build-link-flags,$(1)))

$(O)/$(1)$(BIN_EXT) : $(O)/.TRACK-LDFLAGS $(call target-obj,$(1))
	$$(QUIET_LINK)$$(CCLD) -o $$@ $$(call target-obj,$(1)) $$(ALL_LDFLAGS) $$(ldflags-$(1))
endef

define SLIB-LINK
$(eval $(call build-link-flags,$(1)))

$(O)/$(1) : $(O)/.TRACK-ARFLAGS $(call target-obj,$(1))
	$$(QUIET_AR)$$(AR) -o $$@ $$(call target-obj,$(1)) $$(ALL_ARFLAGS) $$(arflags-$(1))

endef


$(foreach target,$(TARGETS),$(eval $(call BIN-LINK,$(target))))
$(foreach slib,$(TARGET_STATIC_LIBS),$(eval $(call SLIB-LINK,$(slib))))

$(O)/%.tab.h $(O)/%.tab.c : %.y
	$(QUIET_BISON)$(BISON) --locations -d \
		-p '$(parser-prefix)' -k -b $* $<

$(O)/%.ll.c : %.l
	$(QUIET_FLEX)$(FLEX) -P '$(parser-prefix)' --bison-locations --bison-bridge -o $@ $<

$(O)/%.o: %.c $(O)/.TRACK-CFLAGS
	$(QUIET_CC)$(CC) $(dep-gen) -c -o $@ $< $(ALL_CFLAGS) $(cflags-$*)

$(O)/%.o: %.cc $(O)/.TRACK-CXXFLAGS
	$(QUIET_CXX)$(CXX) $(dep-gen) -c -o $@ $< $(ALL_CXXFLAGS) $(cxxflags-$*)

$(O)/%.o : %.S $(O)/.TRACK-ASFLAGS
	$(QUIET_AS)$(AS) -c $(ALL_ASFLAGS) $< -o $@

ifndef NO_INSTALL
# link against things here
PREFIX  ?= $(HOME)
# install into here
DESTDIR ?= $(PREFIX)
# binarys go here
BINDIR  ?= $(DESTDIR)/bin
.PHONY: install %.install
%.install: %
	mkdir -p $(BINDIR)
	install $* $(BINDIR)
install: $(foreach target,$(TARGETS),$(target).install)
endif

obj-all = $(foreach target,$(TARGETS),$(obj-$(target)))
obj-trash = $(foreach obj,$(obj-all),$(call OBJ_TRASH,$(obj)))

.PHONY: clean %.clean
%.clean :
	$(RM) $(call target-obj,$*) $(O)/$* $(TARGET_TRASH) $(call target-dep,$*)

clean:	$(addsuffix .clean,$(TARGETS))
	$(RM) $(TRASH) $(obj-trash)

.PHONY: watch
watch:
	@while true; do \
		echo $(MAKEFLAGS); \
		$(MAKE) $(MAKEFLAGS) -rR --no-print-directory; \
		inotifywait -q \
		  \
		 -- $$(find . \
		        -name '*.c' \
			-or -name '*.h' \
			-or -name 'Makefile' \
			-or -name '*.mk' ); \
		echo "Rebuilding...";	\
	done

.PHONY: show-targets
show-targets:
	@echo $(TARGETS)

.PHONY: show-cflags
show-cflags:
	@echo $(ALL_CFLAGS) $(cflags-$(FILE:.c=))

deps = $(foreach target,$(TARGETS),$(call target-dep,$(target)))
-include $(deps)

# COMP 428/6281 Assignment 2 -- project template
#
#   make                build bin/sequential bin/hypercube bin/pool
#   make test           unit tests (Google Test) + MPI smoke test
#   make unit           unit tests only
#   make smoke          MPI smoke test only
#   make clean
#
# Google Test must be downloaded once first:  bash scripts/get_googletest.sh
# On a cluster: `module load` an OpenMPI module before running make.

MPICXX   ?= mpicxx
ARCH     ?=
CXXFLAGS ?= -O2 $(ARCH) -std=c++17 -Wall -Wextra -Wpedantic
CPPFLAGS += -Iinclude
MPIRUN   ?= mpirun
MPIFLAGS ?= --oversubscribe

OBJDIR   := build
LIB_SRC  := src/common.cpp src/sequential_quicksort.cpp src/hypercube_quicksort.cpp src/pool_quicksort.cpp
LIB_OBJ  := $(LIB_SRC:src/%.cpp=$(OBJDIR)/%.o)
PROGS    := bin/sequential bin/hypercube bin/pool

GTEST_DIR := third_party/googletest/googletest
GTEST_LIB := $(OBJDIR)/gtest/libgtest.a
TEST_BIN  := bin/unit_tests
TEST_SRC  := $(wildcard tests/*.cpp)

.PHONY: all test unit smoke clean check-gtest

all: $(PROGS)

bin/%: apps/%_main.cpp $(LIB_OBJ) | bin
	$(MPICXX) $(CPPFLAGS) $(CXXFLAGS) $^ -o $@

$(OBJDIR)/%.o: src/%.cpp $(wildcard include/*.hpp) | $(OBJDIR)
	$(MPICXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

# ---- Google Test, built from source -----------------------------------------
check-gtest:
	@test -f $(GTEST_DIR)/src/gtest-all.cc || { \
	  echo "error: Google Test not found in third_party/googletest."; \
	  echo "       Run once (needs internet):  bash scripts/get_googletest.sh"; \
	  exit 1; }

$(GTEST_LIB): | check-gtest
	mkdir -p $(OBJDIR)/gtest
	$(MPICXX) -std=c++17 -O1 -pthread -isystem $(GTEST_DIR)/include -I$(GTEST_DIR) \
	    -c $(GTEST_DIR)/src/gtest-all.cc -o $(OBJDIR)/gtest/gtest-all.o
	$(MPICXX) -std=c++17 -O1 -pthread -isystem $(GTEST_DIR)/include -I$(GTEST_DIR) \
	    -c $(GTEST_DIR)/src/gtest_main.cc -o $(OBJDIR)/gtest/gtest_main.o
	ar rcs $@ $(OBJDIR)/gtest/gtest-all.o $(OBJDIR)/gtest/gtest_main.o

$(TEST_BIN): $(TEST_SRC) $(LIB_OBJ) $(GTEST_LIB) | bin
	$(MPICXX) $(CPPFLAGS) -isystem $(GTEST_DIR)/include $(CXXFLAGS) -pthread \
	    $(TEST_SRC) $(LIB_OBJ) $(GTEST_LIB) -o $@

# ---- tests -------------------------------------------------------------------
unit: $(TEST_BIN)
	./$(TEST_BIN)

smoke: $(PROGS)
	MPIRUN="$(MPIRUN)" MPIFLAGS="$(MPIFLAGS)" bash tests/mpi_smoke.sh

# Runs both even if the unit tests fail, then fails if either failed.
test: $(PROGS) $(TEST_BIN)
	@rc=0; ./$(TEST_BIN) || rc=1; \
	MPIRUN="$(MPIRUN)" MPIFLAGS="$(MPIFLAGS)" bash tests/mpi_smoke.sh || rc=1; \
	if [ $$rc -ne 0 ]; then echo "make test: FAILED"; else echo "make test: all passed"; fi; \
	exit $$rc

bin $(OBJDIR):
	mkdir -p $@

clean:
	rm -rf $(OBJDIR) bin

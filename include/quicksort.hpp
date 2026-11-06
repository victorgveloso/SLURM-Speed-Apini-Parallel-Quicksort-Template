// quicksort.hpp -- THE PART YOU IMPLEMENT.
// The three functions below are stubs in src/. The programs in apps/ already
// call them, time them and verify their output.
#pragma once

#include <mpi.h>

#include <vector>

// Requirement 1. Sorts `a` in non-decreasing order, in place.
// Implemented in src/sequential_quicksort.cpp. Tested by tests/test_sequential.cpp.
void sequential_quicksort(std::vector<int>& a);

// Requirement 2, statically assigned version: hypercube quicksort
// (textbook Problem 9.17, Algorithm 9.9, Figure 9.21).
// Implemented in src/hypercube_quicksort.cpp.
//
// Called by every process of `cube`, whose size is a power of two (2^d).
// `block` is this process' share of the input (about n/p elements).
// Returns this process' part of the result: every returned block is sorted,
// and every element on rank r is <= every element on rank r+1. Blocks may
// have any size (including zero); apps/hypercube_main.cpp gathers them in
// rank order.
std::vector<int> hypercube_quicksort(std::vector<int> block, MPI_Comm cube);

// Requirement 2, pool-of-tasks version (textbook Section 3.6.3).
// Implemented in src/pool_quicksort.cpp.
//
// Called by every process of `comm`. On rank 0, `a` holds the whole input
// and must hold it sorted on return. On the other ranks `a` is empty and is
// ignored. Rank 0 is the master; ranks 1..p-1 are workers. With p = 1 the
// master has to do all the work itself.
void pool_quicksort(std::vector<int>& a, MPI_Comm comm);

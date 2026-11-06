// common.hpp -- the "boring parts", already done for you: command-line
// options, input generation, verification, host mapping and CSV output.
// You should not need to change this file.
#pragma once

#include <mpi.h>

#include <string>
#include <vector>

struct Options {
    long n = 1000000;          // --n <count>   number of elements to sort
    unsigned seed = 1;         // --seed <s>    input generator seed
    bool header = false;       // --header      print the CSV header first
    bool show_mapping = false; // --show-mapping  print "rank r on host" to stderr
};

// Parses the options above. Prints usage and exits on --help or bad input.
Options parse_options(int argc, char** argv);

// n pseudo-random ints in [0, 2^30], the same for a given (n, seed) on every
// machine, so all versions sort exactly the same input.
std::vector<int> random_input(long n, unsigned seed);

// True if `result` is `input` sorted (same elements, non-decreasing order).
bool is_sorted_permutation(const std::vector<int>& input, const std::vector<int>& result);

// Number of distinct host names among the processes of `comm` (collective;
// the result is valid on rank 0). With print = true, rank 0 also prints the
// rank -> host mapping to stderr.
int count_distinct_hosts(MPI_Comm comm, bool print);

// One CSV row on stdout:  version,p,nodes,n,seconds,ok
void print_csv_header();
void print_csv_row(const std::string& version, int p, int nodes, long n,
                   double seconds, bool ok);

// Splits n elements as evenly as possible into p blocks (block r gets
// counts[r] elements starting at displs[r]), for MPI_Scatterv/MPI_Gatherv.
void block_layout(long n, int p, std::vector<int>& counts, std::vector<int>& displs);

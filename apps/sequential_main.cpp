// bin/sequential -- Requirement 1: times sequential_quicksort on one node.
//   ./bin/sequential --n 1000000 --seed 1 [--header]
// Prints: version,p,nodes,n,seconds,ok   (exit code 1 if the output is wrong)
#include "common.hpp"
#include "quicksort.hpp"

#include <chrono>

int main(int argc, char** argv) {
    const Options o = parse_options(argc, argv);
    const std::vector<int> input = random_input(o.n, o.seed);
    std::vector<int> a = input;

    const auto t0 = std::chrono::steady_clock::now();
    sequential_quicksort(a);
    const auto t1 = std::chrono::steady_clock::now();

    const bool ok = is_sorted_permutation(input, a);
    if (o.header) print_csv_header();
    print_csv_row("sequential", 1, 1, o.n, std::chrono::duration<double>(t1 - t0).count(), ok);
    return ok ? 0 : 1;
}

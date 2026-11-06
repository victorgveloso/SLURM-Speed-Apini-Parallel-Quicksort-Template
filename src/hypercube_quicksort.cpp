#include "quicksort.hpp"

// Requirement 2, statically assigned version: hypercube quicksort
// (textbook Problem 9.17, Algorithm 9.9, Figure 9.21).
// See include/quicksort.hpp for the exact contract.
//
// TODO(student): implement the d splits of Algorithm 9.9 and the final local
// sort. Questions to settle before you write code:
//   * which bit of the rank is used at split i, and who is the partner?
//   * how do all processes of a subcube agree on the same pivot?
//   * how does the receiver learn how many elements are coming?
//   * how do you restrict the next pivot choice to your own subcube?
//     (MPI_Comm_split is one answer.)
// The stub returns the block unchanged, so bin/hypercube reports ok=0.
std::vector<int> hypercube_quicksort(std::vector<int> block, MPI_Comm cube) {
    (void)cube;  // remove this line when you implement the function
    return block;
}

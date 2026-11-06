#include "quicksort.hpp"

// Requirement 2, pool-of-tasks version (textbook Section 3.6.3).
// See include/quicksort.hpp for the exact contract.
//
// TODO(student): rank 0 (master) creates tasks and hands them out; ranks
// 1..p-1 (workers) sort tasks until told to stop. Questions to settle:
//   * how are tasks created so that sorting each one sorts the whole array?
//   * how many tasks, and of what size, keep every worker busy?
//   * how does a worker know whether a message is work or "stop"?
//     (message tags; MPI_Probe + MPI_Get_count for the size)
//   * how does the master know where a returned task belongs?
//   * what happens with p = 1 (no workers)?
// The stub leaves the array unsorted, so bin/pool reports ok=0.
void pool_quicksort(std::vector<int>& a, MPI_Comm comm) {
    (void)a;     // remove these lines when you implement the function
    (void)comm;
}

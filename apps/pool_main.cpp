// bin/pool -- Requirement 2 (pool of tasks): runs pool_quicksort.
//   mpirun -np P ./bin/pool --n 1000000 --seed 1 [--header] [--show-mapping]
// Prints on rank 0: version,p,nodes,n,seconds,ok   (exit code 1 if wrong)
// Timed region: "unsorted on rank 0" -> "sorted on rank 0".
#include "common.hpp"
#include "quicksort.hpp"

#include <mpi.h>

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);
    const Options o = parse_options(argc, argv);
    int rank, p;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &p);
    const int nodes = count_distinct_hosts(MPI_COMM_WORLD, o.show_mapping);

    std::vector<int> input, a;
    if (rank == 0) {
        input = random_input(o.n, o.seed);
        a = input;
    }

    MPI_Barrier(MPI_COMM_WORLD);
    const double t0 = MPI_Wtime();
    pool_quicksort(a, MPI_COMM_WORLD);
    const double seconds = MPI_Wtime() - t0;

    int exit_code = 0;
    if (rank == 0) {
        const bool ok = is_sorted_permutation(input, a);
        if (o.header) print_csv_header();
        print_csv_row("pool", p, nodes, o.n, seconds, ok);
        exit_code = ok ? 0 : 1;
    }
    MPI_Finalize();
    return exit_code;
}

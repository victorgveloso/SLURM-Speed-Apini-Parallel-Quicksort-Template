// bin/hypercube -- Requirement 2 (statically assigned): runs hypercube_quicksort.
//   mpirun -np P ./bin/hypercube --n 1000000 --seed 1 [--header] [--show-mapping]
// Prints on rank 0: version,p,nodes,n,seconds,ok   (exit code 1 if wrong)
//
// Done for you: input on rank 0, distribution in blocks of ~n/p, collection
// in rank order, timing and verification. The timed region is
// "unsorted on rank 0" -> "sorted on rank 0", i.e. it includes the scatter
// and the gather. If you report something else, say so in your write-up.
#include "common.hpp"
#include "quicksort.hpp"

#include <mpi.h>

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);
    const Options o = parse_options(argc, argv);
    int world_rank, world_size;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);
    const int nodes = count_distinct_hosts(MPI_COMM_WORLD, o.show_mapping);

    // Algorithm 9.9 needs 2^d processes. For p = 6, 10, 12 this template uses
    // the largest power of two <= p and leaves the other ranks idle (they
    // still count as p in the CSV). You may handle this differently.
    int d = 0;
    while ((2 << d) <= world_size) ++d;
    const int active = 1 << d;
    MPI_Comm cube;
    MPI_Comm_split(MPI_COMM_WORLD, world_rank < active ? 0 : MPI_UNDEFINED, world_rank, &cube);

    int exit_code = 0;
    if (cube != MPI_COMM_NULL) {
        int rank;
        MPI_Comm_rank(cube, &rank);
        std::vector<int> input, output;
        if (rank == 0) input = random_input(o.n, o.seed);

        std::vector<int> counts, displs;
        block_layout(o.n, active, counts, displs);

        MPI_Barrier(cube);
        const double t0 = MPI_Wtime();

        std::vector<int> block(static_cast<std::size_t>(counts[rank]));
        MPI_Scatterv(input.data(), counts.data(), displs.data(), MPI_INT, block.data(),
                     counts[rank], MPI_INT, 0, cube);

        std::vector<int> mine = hypercube_quicksort(std::move(block), cube);

        // Blocks may have changed size: gather the sizes, then the data.
        int my_n = static_cast<int>(mine.size());
        MPI_Gather(&my_n, 1, MPI_INT, counts.data(), 1, MPI_INT, 0, cube);
        long total = 0;
        if (rank == 0) {
            for (int r = 0; r < active; ++r) {
                displs[r] = static_cast<int>(total);
                total += counts[r];
            }
            output.resize(static_cast<std::size_t>(total));
        }
        MPI_Gatherv(mine.data(), my_n, MPI_INT, output.data(), counts.data(), displs.data(),
                    MPI_INT, 0, cube);
        const double seconds = MPI_Wtime() - t0;

        if (rank == 0) {
            const bool ok = total == o.n && is_sorted_permutation(input, output);
            if (o.header) print_csv_header();
            print_csv_row("hypercube", world_size, nodes, o.n, seconds, ok);
            exit_code = ok ? 0 : 1;
        }
        MPI_Comm_free(&cube);
    }
    MPI_Finalize();
    return exit_code;
}

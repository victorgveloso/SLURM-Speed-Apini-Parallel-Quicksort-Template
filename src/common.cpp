#include "common.hpp"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <set>

namespace {

[[noreturn]] void usage(const char* prog, int code) {
    std::fprintf(stderr,
                 "usage: %s [--n COUNT] [--seed S] [--header] [--show-mapping]\n"
                 "  --n COUNT       number of elements to sort (default 1000000)\n"
                 "  --seed S        input generator seed (default 1)\n"
                 "  --header        print the CSV header before the result row\n"
                 "  --show-mapping  print which host every rank runs on (stderr)\n",
                 prog);
    std::exit(code);
}

}  // namespace

Options parse_options(int argc, char** argv) {
    Options o;
    for (int i = 1; i < argc; ++i) {
        const std::string a = argv[i];
        auto value = [&]() -> const char* {
            if (i + 1 >= argc) usage(argv[0], 2);
            return argv[++i];
        };
        if (a == "--n") {
            char* end = nullptr;
            o.n = std::strtol(value(), &end, 10);
            if (*end != '\0' || o.n < 0) usage(argv[0], 2);
        } else if (a == "--seed") {
            o.seed = static_cast<unsigned>(std::strtoul(value(), nullptr, 10));
        } else if (a == "--header") {
            o.header = true;
        } else if (a == "--show-mapping") {
            o.show_mapping = true;
        } else if (a == "--help" || a == "-h") {
            usage(argv[0], 0);
        } else {
            std::fprintf(stderr, "unknown option: %s\n", a.c_str());
            usage(argv[0], 2);
        }
    }
    return o;
}

std::vector<int> random_input(long n, unsigned seed) {
    std::mt19937 gen(seed);
    std::uniform_int_distribution<int> dist(0, 1 << 30);
    std::vector<int> v(static_cast<std::size_t>(n));
    for (auto& x : v) x = dist(gen);
    return v;
}

bool is_sorted_permutation(const std::vector<int>& input, const std::vector<int>& result) {
    std::vector<int> expected = input;
    std::sort(expected.begin(), expected.end());
    return expected == result;
}

int count_distinct_hosts(MPI_Comm comm, bool print) {
    int rank, p, len;
    MPI_Comm_rank(comm, &rank);
    MPI_Comm_size(comm, &p);
    char name[MPI_MAX_PROCESSOR_NAME] = {};
    MPI_Get_processor_name(name, &len);
    std::vector<char> all(rank == 0 ? static_cast<std::size_t>(p) * MPI_MAX_PROCESSOR_NAME : 0);
    MPI_Gather(name, MPI_MAX_PROCESSOR_NAME, MPI_CHAR, all.data(), MPI_MAX_PROCESSOR_NAME,
               MPI_CHAR, 0, comm);
    if (rank != 0) return 0;
    std::set<std::string> hosts;
    for (int r = 0; r < p; ++r) {
        const std::string h(&all[static_cast<std::size_t>(r) * MPI_MAX_PROCESSOR_NAME]);
        hosts.insert(h);
        if (print) std::fprintf(stderr, "rank %d on %s\n", r, h.c_str());
    }
    const int distinct = static_cast<int>(hosts.size());
    if (distinct < p)
        std::fprintf(stderr, "warning: %d ranks share %d host(s); the assignment wants "
                             "one worker per node (mpirun --map-by node, see README)\n", p, distinct);
    return distinct;
}

void print_csv_header() { std::printf("version,p,nodes,n,seconds,ok\n"); }

void print_csv_row(const std::string& version, int p, int nodes, long n, double seconds,
                   bool ok) {
    std::printf("%s,%d,%d,%ld,%.6f,%d\n", version.c_str(), p, nodes, n, seconds, ok ? 1 : 0);
    std::fflush(stdout);
}

void block_layout(long n, int p, std::vector<int>& counts, std::vector<int>& displs) {
    counts.assign(static_cast<std::size_t>(p), 0);
    displs.assign(static_cast<std::size_t>(p), 0);
    for (int r = 0; r < p; ++r) {
        counts[r] = static_cast<int>(n / p + (r < n % p ? 1 : 0));
        if (r > 0) displs[r] = displs[r - 1] + counts[r - 1];
    }
}

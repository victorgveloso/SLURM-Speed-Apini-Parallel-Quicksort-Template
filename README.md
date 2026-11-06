# Parallel Quicksort: project template

This template holds everything that is *not* the assignment: the build, the
tests, the input generator, timing and verification, the CSV output, the
OpenMPI hostfile, the SLURM jobs and the plots. You write the three sorting
functions. Everything else already works.

```
include/quicksort.hpp       the 3 functions you implement (contracts documented here)
src/sequential_quicksort.cpp   TODO  Requirement 1
src/hypercube_quicksort.cpp    TODO  Requirement 2, statically assigned (Alg. 9.9)
src/pool_quicksort.cpp         TODO  Requirement 2, pool of tasks
include/common.hpp, src/common.cpp   options, input, verification, host mapping, CSV
apps/*_main.cpp             the programs: input -> your function -> time -> verify -> CSV
tests/test_sequential.cpp   Google Test unit tests for sequential_quicksort
tests/mpi_smoke.sh          runs every program for several p and n, checks ok=1
cluster/run_apini.sh        benchmark sweep on apini (course hostfile, p = 1..8)
speed/run_on_speed.sh       one command for the Speed cluster (tests or benchmark)
scripts/get_googletest.sh   downloads Google Test 1.14.0 into third_party/
scripts/plot_speedup.py     speedup plots (Requirement 4)
```

## Quickstart (your machine)

You need an MPI compiler (`mpicxx`) and `mpirun`: on macOS `brew install open-mpi`,
on Ubuntu `sudo apt install libopenmpi-dev openmpi-bin`.

```bash
bash scripts/get_googletest.sh     # once; needs internet
make                               # bin/sequential bin/hypercube bin/pool
make test                          # unit tests + MPI smoke test
./bin/sequential --n 1000000 --header
mpirun --oversubscribe -np 4 ./bin/hypercube --n 1000000 --show-mapping
mpirun --oversubscribe -np 4 ./bin/pool --n 1000000
```

**`make test` fails until you implement the functions.** That is expected:
the stubs do nothing, so the unit tests and most smoke runs report failures.
(A few cases pass even with the stubs, such as empty input.)
Work through the TODOs:

1. `src/sequential_quicksort.cpp`. Make `make unit` pass.
2. `src/hypercube_quicksort.cpp`. Make the hypercube rows of `make smoke` pass.
3. `src/pool_quicksort.cpp`. Make the pool rows pass.

Every program prints one CSV row: `version,p,nodes,n,seconds,ok`.
`ok = 1` means the output is exactly the sorted input. `nodes` is the number of
distinct hosts the ranks ran on. The exit code is 1 when `ok = 0`, so scripts
notice failures. Options: `--n`, `--seed`, `--header`, `--show-mapping`, `--help`.

Useful while developing:
```bash
make unit                                      # only the Google Test tests
./bin/unit_tests --gtest_filter='*Reverse*'    # only some tests
PS="2 4" NS="1000" make smoke                  # a quick smoke test
```

## Running on apini (p = 1, 2, 4, 6, 8)

apini has no job scheduler: you run `mpirun` yourself with the course hostfile
`/media/pkg/apini-scripts/apini_hostfile`.

1. Build: `make` (`mpicxx` is on the PATH on apini).
2. Check the mapping (every rank on a different host):
   ```bash
   mpirun -np 8 --map-by node --hostfile /media/pkg/apini-scripts/apini_hostfile \
       ./bin/hypercube --n 16 --show-mapping
   ```
   `--map-by node` places the ranks round robin, one per node. Without it,
   OpenMPI fills the first node's slots first and several ranks share a machine.
3. Benchmark: `bash cluster/run_apini.sh`. It writes `results/apini_<date>.csv`
   for p in {1, 2, 4, 6, 8}; the sequential runs also go through `mpirun -np 1`,
   so they run on a cluster node and not on the machine you are logged in to.

## Running on Speed (12 and 16 workers)

From a Speed login node, inside your copy of this project:

```bash
bash scripts/get_googletest.sh       # once (compute nodes may have no internet)
bash speed/run_on_speed.sh           # submit the tests, wait, print RESULT: PASS/FAIL
bash speed/run_on_speed.sh bench     # submit the benchmark sweep (Requirements 3 and 4)
```

`run_on_speed.sh` copies the project to `/speed-scratch/$USER/quicksort/src`
and submits two jobs:
* a build and test job on one node: unit tests plus an oversubscribed smoke test;
* if that passes, a multi-node job with one rank per node. It checks that every
  run sorts correctly **and** ran on p distinct nodes.

Everything goes to `/speed-scratch/$USER/quicksort/`:

| folder | contents |
|---|---|
| `src/` | the staged code (built there) |
| `input/` | the configuration of each submission |
| `output/` | test CSV, `summary.txt`, `*.status`, `bench_<job>.csv`, plots |
| `logs/` | SLURM output and the per-job logs |
| `work/` | hostfiles, job ids |

Sub-commands: `submit`, `status`, `wait`, `report`, `bench`. The last line of
`report` is `RESULT: PASS` (exit 0), `RESULT: FAIL` (exit 1) or
`RESULT: PENDING` (exit 2). Settings go in environment variables:

```bash
NODES=8 bash speed/run_on_speed.sh                    # if you cannot get 16 nodes
MODULES="openmpi/4.1.6" PARTITION=ps bash speed/run_on_speed.sh
PS="1 2 4 8 16" NS="1000000 10000000" REPS=5 bash speed/run_on_speed.sh bench
```

## Plots (Requirement 4)

```bash
python3 scripts/plot_speedup.py results/apini_<date>.csv --out results/plots
```
This writes `summary.csv` (T_p, T_seq, speedup, efficiency) and two PNGs:
speedup vs. workers (one line per n) and speedup vs. input size (one line per
p). The PNGs need matplotlib: `pip install --user matplotlib`.

## Common pitfalls

* **`mpicxx: command not found` on a cluster.** Run `module load` with an
  OpenMPI module first (`module avail openmpi`). Batch jobs do not inherit
  your interactive modules; the scripts in `speed/` load one for you.
* **`Illegal instruction` on some nodes.** You built with `-march=native` on
  one CPU model and ran on another. `ARCH` is empty by default; keep it empty
  on clusters with mixed node types.
* **All ranks on one node.** OpenMPI fills a node's slots first unless you
  pass `--map-by node` (apini) or use a `slots=1` hostfile (the Speed jobs).
  Check the `nodes` column or `--show-mapping`.
* **"There are not enough slots available".** On your laptop, add
  `--oversubscribe` (`make test` already does). On apini, it means you asked
  for more ranks than the hostfile has slots.
* **`--bind-to core` errors on macOS.** Use `--bind-to none` locally.
* **macOS ships bash 3.2.** The scripts avoid bash 4 features (`mapfile`,
  associative arrays). Keep it that way if you edit them.
* **Google Test not found.** Run `bash scripts/get_googletest.sh` once. It is
  not committed, and compute nodes usually cannot download it.
* **Timing.** The timed region is "unsorted on rank 0" to "sorted on rank 0"
  (distribution, sort, collection). Laptop timings with `--oversubscribe` are
  not results; benchmark on the clusters.
* **p = 6, 10, 12 for the hypercube.** `apps/hypercube_main.cpp` uses the
  largest power of two ≤ p and leaves the other ranks idle. You may handle
  this differently; explain your choice in the report.

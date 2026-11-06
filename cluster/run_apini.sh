#!/usr/bin/env bash
# Benchmark sweep on apini (no SLURM): mpirun with the course hostfile,
#   mpirun -np X --map-by node --hostfile /media/pkg/apini-scripts/apini_hostfile ...
# for X in 1 2 4 6 8 (--map-by node: one rank per node, round robin).
#   bash cluster/run_apini.sh                      # writes results/apini_<date>.csv
#   REPS=5 NS="100000 1000000" bash cluster/run_apini.sh
# Then:  python3 scripts/plot_speedup.py results/apini_<date>.csv
set -euo pipefail
cd "$(dirname "$0")/.."

HOSTFILE=${HOSTFILE:-/media/pkg/apini-scripts/apini_hostfile}
[ -r "$HOSTFILE" ] || { echo "error: hostfile $HOSTFILE not readable (are you on apini?)" >&2; exit 1; }
REPS=${REPS:-3}
NS=${NS:-"100000 1000000 10000000 50000000"}
PS=${PS:-"1 2 4 6 8"}               # the apini worker counts of the assignment
# Apini nodes have two interfaces; MPI traffic over ens19 (33.33.33.x) times
# out between nodes ("connect() to 33.33.33.x failed"), so use ens18 only.
NET=${NET---mca btl_tcp_if_include ens18 --mca oob_tcp_if_include ens18}
MPIRUN="mpirun $NET --map-by node --hostfile $HOSTFILE ${MPIRUN_EXTRA:-}"

mkdir -p results
CSV=results/apini_$(date +%Y%m%d_%H%M%S).csv
make
$MPIRUN -np 1 ./bin/sequential --n 1 --header | head -1 > "$CSV"

# Show the mapping once: every rank must be on a different node.
$MPIRUN -np "$(echo $PS | tr ' ' '\n' | sort -n | tail -1)" ./bin/hypercube --n 16 --show-mapping >/dev/null || true   # mapping only; ok may be 0 until you implement it

for rep in $(seq 1 "$REPS"); do
    seed=$((100 + rep))
    for N in $NS; do
        $MPIRUN -np 1 ./bin/sequential --n "$N" --seed "$seed" | tee -a "$CSV"   # on a cluster node
        for P in $PS; do
            $MPIRUN -np "$P" ./bin/hypercube --n "$N" --seed "$seed" | tee -a "$CSV"
            $MPIRUN -np "$P" ./bin/pool --n "$N" --seed "$seed" | tee -a "$CSV"
        done
    done
done
echo "results: $CSV"

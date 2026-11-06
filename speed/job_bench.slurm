#!/bin/bash
# Benchmark sweep for Requirements 3 and 4 on Speed: sequential on one node,
# then hypercube and pool for every p in $PS, one rank per node.
# Submit with:  bash speed/run_on_speed.sh bench
# Results: $OUTPUT/bench_<job>.csv  (plot with scripts/plot_speedup.py)
#SBATCH --job-name=qs_bench
#SBATCH --nodes=16
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --exclusive                # nobody else on our nodes while timing
#SBATCH --mem=4G
#SBATCH --time=02:00:00

set -uo pipefail
. "$SRC/speed/env.sh"
JOB=$SLURM_JOB_ID
LOG=$LOGS/bench_${JOB}.log
CSV=$OUTPUT/bench_${JOB}.csv
exec > >(tee -a "$LOG") 2>&1
echo "== bench on $SLURM_JOB_NUM_NODES nodes ($SLURM_JOB_NODELIST) at $(date)"

qs_load_mpi || exit 1
cd "$SRC" || exit 1
make ARCH="$ARCH" || exit 1

HOSTFILE=$WORK/hosts.$JOB
qs_hostfile "$HOSTFILE"
MPIRUN="mpirun --hostfile $HOSTFILE --map-by ppr:1:node ${MPIRUN_EXTRA:-}"

REPS=${REPS:-3}
NS=${NS:-"100000 1000000 10000000 50000000"}
PS=${PS:-"1 2 4 6 8 12 16"}
PS_RUN=""
for P in $PS; do [ "$P" -le "$SLURM_JOB_NUM_NODES" ] && PS_RUN="$PS_RUN $P"; done

./bin/sequential --n 1 --header | head -1 > "$CSV"
$MPIRUN -np "${PS_RUN##* }" ./bin/hypercube --n 16 --show-mapping >/dev/null
for rep in $(seq 1 "$REPS"); do
    seed=$((100 + rep))
    for N in $NS; do
        ./bin/sequential --n "$N" --seed "$seed" >> "$CSV"
        for P in $PS_RUN; do
            $MPIRUN -np "$P" ./bin/hypercube --n "$N" --seed "$seed" >> "$CSV"
            $MPIRUN -np "$P" ./bin/pool --n "$N" --seed "$seed" >> "$CSV"
        done
    done
done
echo "results: $CSV"
if command -v python3 >/dev/null 2>&1; then
    python3 scripts/plot_speedup.py "$CSV" --out "$OUTPUT/plots_$JOB" || true
fi

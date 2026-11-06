#!/bin/bash
# Job 2 of 2: multi-node correctness test, one MPI rank per node. For every
# p in $PS (that fits in the allocation) it checks that bin/hypercube and
# bin/pool sort correctly (ok = 1, exit 0) AND ran on p distinct nodes.
# Submitted by run_on_speed.sh, which sets --nodes.
#SBATCH --job-name=qs_mpi_test
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00

set -uo pipefail
. "$SRC/speed/env.sh"
NAME=mpi_test
JOB=$SLURM_JOB_ID
LOG=$LOGS/${NAME}_${JOB}.log
CSV=$OUTPUT/${NAME}_${JOB}.csv
exec > >(tee -a "$LOG") 2>&1
echo "== $NAME on $SLURM_JOB_NUM_NODES nodes ($SLURM_JOB_NODELIST) at $(date)"

qs_load_mpi || { qs_status "$NAME" FAIL "no OpenMPI toolchain"; exit 1; }
cd "$SRC" || { qs_status "$NAME" FAIL "missing $SRC"; exit 1; }

HOSTFILE=$WORK/hosts.$JOB
qs_hostfile "$HOSTFILE"
echo "hostfile:"; cat "$HOSTFILE"
MPIRUN="mpirun --hostfile $HOSTFILE --map-by ppr:1:node ${MPIRUN_EXTRA:-}"

PS=${PS:-"1 2 4 6 8 12 16"}
N=${TEST_N:-1000003}
PS_RUN=""
for P in $PS; do [ "$P" -le "$SLURM_JOB_NUM_NODES" ] && PS_RUN="$PS_RUN $P"; done
echo "process counts:$PS_RUN   (n = $N and n = 0, 1, 5)"

./bin/sequential --n 1 --header | head -1 > "$CSV"
fail=0 runs=0
for P in $PS_RUN; do
    for prog in hypercube pool; do
        for n in "$N" 0 1 5; do
            runs=$((runs + 1))
            out=$($MPIRUN -np "$P" "./bin/$prog" --n "$n" --seed 11 2>"$WORK/err.$JOB"); rc=$?
            row=$(echo "$out" | grep -E "^$prog," | tail -1)
            [ -n "$row" ] && echo "$row" >> "$CSV"
            nodes=$(echo "$row" | cut -d, -f3)    # version,p,nodes,n,seconds,ok
            ok=$(echo "$row" | cut -d, -f6)
            if [ $rc -eq 0 ] && [ "$ok" = 1 ] && [ "$nodes" = "$P" ]; then
                echo "PASS $prog p=$P n=$n"
            else
                echo "FAIL $prog p=$P n=$n (exit $rc, ok=${ok:-none}, nodes=${nodes:-?}) $(tail -2 "$WORK/err.$JOB" | tr '\n' ' ')"
                fail=$((fail + 1))
            fi
        done
    done
done
rm -f "$WORK/err.$JOB"

echo "== $NAME: $((runs - fail)) of $runs checks passed"
if [ $fail -eq 0 ]; then
    qs_status "$NAME" PASS "$runs checks on p =$PS_RUN"
else
    qs_status "$NAME" FAIL "$fail of $runs checks failed (see $LOG)"
    exit 1
fi

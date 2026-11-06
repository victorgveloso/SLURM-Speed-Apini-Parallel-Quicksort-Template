#!/usr/bin/env bash
# MPI smoke test: runs every program for several process counts and sizes and
# checks that each run prints ok=1 and exits with 0. Checks correctness only.
#
#   bash tests/mpi_smoke.sh                     # on your machine (oversubscribed)
#   PS="1 2 4" NS="1000" bash tests/mpi_smoke.sh
#   MPIRUN="mpirun --map-by node --hostfile /media/pkg/apini-scripts/apini_hostfile" MPIFLAGS= \
#       PS="1 2 4 6 8 10" bash tests/mpi_smoke.sh   # on apini, one rank per node
set -u
cd "$(dirname "$0")/.."
MPIRUN=${MPIRUN:-mpirun}
MPIFLAGS=${MPIFLAGS---oversubscribe}
PS=${PS:-"1 2 3 4 6 8"}
NS=${NS:-"0 1 7 1000 100003"}
fail=0 runs=0

check() {  # check <description> <command...>
    local desc=$1 out rc ok
    shift
    out=$("$@" 2>&1)
    rc=$?
    ok=$(echo "$out" | grep -E '^(sequential|hypercube|pool),' | tail -1 | awk -F, '{print $NF}')
    runs=$((runs + 1))
    if [ $rc -eq 0 ] && [ "$ok" = "1" ]; then
        echo "ok   $desc"
    else
        echo "FAIL $desc (exit $rc, ok=${ok:-none})"
        echo "$out" | tail -3 | sed 's/^/       /'
        fail=$((fail + 1))
    fi
}

for N in $NS; do
    check "sequential n=$N" ./bin/sequential --n "$N"
done
for P in $PS; do
    for N in $NS; do
        # shellcheck disable=SC2086
        check "hypercube p=$P n=$N" $MPIRUN $MPIFLAGS -np "$P" ./bin/hypercube --n "$N"
        # shellcheck disable=SC2086
        check "pool p=$P n=$N" $MPIRUN $MPIFLAGS -np "$P" ./bin/pool --n "$N"
    done
done

if [ $fail -ne 0 ]; then
    echo "mpi_smoke: $fail of $runs runs FAILED"
    exit 1
fi
echo "mpi_smoke: all $runs runs passed"

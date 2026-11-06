#!/bin/bash
# Job 1 of 2: build on one compute node and run the unit tests and the
# single-node (oversubscribed) MPI smoke test. Submitted by run_on_speed.sh.
#SBATCH --job-name=qs_build_test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH --time=00:30:00

set -uo pipefail
. "$SRC/speed/env.sh"
NAME=build_test
LOG=$LOGS/${NAME}_${SLURM_JOB_ID}.log
exec > >(tee -a "$LOG") 2>&1
echo "== $NAME on $(hostname) at $(date)"

fail() { echo "FAIL: $1"; qs_status "$NAME" FAIL "$1"; exit 1; }

qs_load_mpi || fail "no OpenMPI toolchain (set MODULES; see $LOG)"
mpicxx --version | head -1
cd "$SRC" || fail "missing $SRC"
[ -f third_party/googletest/googletest/src/gtest-all.cc ] \
    || fail "Google Test missing: run 'bash scripts/get_googletest.sh' on the login node"

make clean >/dev/null
make ARCH="$ARCH"                                               || fail "build failed"
make unit ARCH="$ARCH"                                          || fail "unit tests failed"
make smoke ARCH="$ARCH" MPIFLAGS="--oversubscribe --bind-to none" || fail "single-node MPI smoke test failed"

qs_status "$NAME" PASS "build + unit tests + single-node MPI smoke test"
echo "PASS: $NAME"

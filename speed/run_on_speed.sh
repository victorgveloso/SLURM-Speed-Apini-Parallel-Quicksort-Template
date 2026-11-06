#!/usr/bin/env bash
# One command to test (or benchmark) the project on the Speed cluster.
# Run it on a Speed login node, from anywhere inside the project:
#
#   bash speed/run_on_speed.sh            # = all: stage, submit, wait, report
#   bash speed/run_on_speed.sh submit     # copy the code to $PROJECT and submit the 2 test jobs
#   bash speed/run_on_speed.sh status     # where are my jobs in the queue?
#   bash speed/run_on_speed.sh wait       # block until both test jobs have finished
#   bash speed/run_on_speed.sh report     # PASS/FAIL from the jobs' status files
#   bash speed/run_on_speed.sh bench      # submit the timing sweep (Requirements 3 and 4)
#
# The last line of `report` (and of `all`) is always one of
#   RESULT: PASS      exit code 0
#   RESULT: FAIL      exit code 1
#   RESULT: PENDING   exit code 2   (jobs still queued or running)
#
# Settings (environment variables):
#   PROJECT       project dir on Speed      (default /speed-scratch/$USER/quicksort)
#   NODES         nodes for the multi-node jobs (default 16; p > NODES is skipped)
#   PS            process counts            (default "1 2 4 6 8 12 16")
#   TEST_N        elements per test run     (default 1000003)
#   NS, REPS      benchmark sizes and repetitions (see speed/job_bench.slurm)
#   MODULES       modules to load           (default: newest "openmpi" module)
#   PARTITION     SLURM partition           (default: the cluster's default)
#   ACCOUNT       SLURM account, if your jobs need one
#   MPIRUN_EXTRA  extra mpirun flags
#   WAIT_TIMEOUT  seconds to wait in `wait`/`all` (default 21600)
#
# Requires bash 3.2+ (works with the old bash on macOS too).
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
. "$REPO/speed/env.sh"
JOBS_FILE=$WORK/jobs.env
NODES=${NODES:-16}
PS=${PS:-"1 2 4 6 8 12 16"}
TEST_N=${TEST_N:-1000003}
WAIT_TIMEOUT=${WAIT_TIMEOUT:-21600}

die() { echo "error: $*" >&2; echo "RESULT: FAIL"; exit 1; }

# Options shared by every sbatch call (one per line, read into an array).
sbatch_common() {
    echo "--parsable"
    echo "--chdir=$SRC"
    echo "--output=$LOGS/%x_%j.out"
    echo "--export=ALL,PROJECT=$PROJECT,SRC=$SRC,MODULES=${MODULES:-},PS=$PS,TEST_N=$TEST_N,ARCH=$ARCH,MPIRUN_EXTRA=${MPIRUN_EXTRA:-},NS=${NS:-},REPS=${REPS:-}"
    [ -n "${PARTITION:-}" ] && echo "--partition=$PARTITION"
    [ -n "${ACCOUNT:-}" ] && echo "--account=$ACCOUNT"
    return 0
}

prepare() {
    command -v sbatch >/dev/null 2>&1 || die "sbatch not found: run this on a Speed login node"
    [ -f "$REPO/third_party/googletest/googletest/src/gtest-all.cc" ] \
        || die "Google Test missing: run 'bash scripts/get_googletest.sh' first (needs internet)"
    mkdir -p "$SRC" "$INPUT" "$OUTPUT" "$LOGS" "$WORK" || die "cannot create $PROJECT"
    if [ "$(cd "$SRC" && pwd)" != "$REPO" ]; then
        echo "staging $REPO -> $SRC"
        if command -v rsync >/dev/null 2>&1; then
            rsync -a --delete --exclude bin/ --exclude build/ --exclude results/ "$REPO/" "$SRC/" \
                || die "rsync failed"
        else
            cp -R "$REPO/." "$SRC/" || die "copy failed"
        fi
    fi
    # Pick the MPI module once, on the login node, so every job uses the same one.
    qs_init_modules
    if [ -z "${MODULES:-}" ] && command -v module >/dev/null 2>&1; then
        MODULES=$(qs_find_mpi_module)
    fi
    [ -n "${MODULES:-}" ] || echo "warning: no openmpi module found; jobs use mpicxx from PATH" >&2
    COMMON=()
    while IFS= read -r line; do COMMON+=("$line"); done < <(sbatch_common)
}

cmd_submit() {
    prepare
    local stamp build mpi
    stamp=$(date +%Y%m%d_%H%M%S)
    rm -f "$OUTPUT/build_test.status" "$OUTPUT/mpi_test.status"
    build=$(sbatch "${COMMON[@]}" "$SRC/speed/job_build_test.slurm") || die "sbatch (build_test) failed"
    build=${build%%;*}
    mpi=$(sbatch "${COMMON[@]}" --nodes="$NODES" --dependency=afterok:"$build" --kill-on-invalid-dep=yes \
                 "$SRC/speed/job_mpi_test.slurm") || die "sbatch (mpi_test) failed"
    mpi=${mpi%%;*}
    printf 'BUILD_JOB=%s\nMPI_JOB=%s\nSUBMITTED=%s\n' "$build" "$mpi" "$stamp" > "$JOBS_FILE"
    {
        echo "# test submission $stamp"
        echo "PROJECT=$PROJECT"; echo "NODES=$NODES"; echo "PS=\"$PS\""; echo "TEST_N=$TEST_N"
        echo "MODULES=\"${MODULES:-}\""; echo "PARTITION=${PARTITION:-}"; echo "ACCOUNT=${ACCOUNT:-}"
        echo "BUILD_JOB=$build"; echo "MPI_JOB=$mpi"
    } > "$INPUT/config_$stamp.env"
    echo "submitted: build_test=$build, mpi_test=$mpi (runs after $build, $NODES nodes)"
    echo "config:    $INPUT/config_$stamp.env"
    echo "logs:      $LOGS"
}

load_jobs() {
    [ -f "$JOBS_FILE" ] || die "nothing submitted yet ($JOBS_FILE missing); run: $0 submit"
    # shellcheck disable=SC1090
    . "$JOBS_FILE"
}

in_queue() { [ -n "$(squeue -h -j "$1" -o %i 2>/dev/null)" ]; }

cmd_status() {
    load_jobs
    local pending=0 j
    for j in "$BUILD_JOB" "$MPI_JOB"; do
        if in_queue "$j"; then
            pending=2
            squeue -h -j "$j" -o "%i %j %T %M elapsed, reason: %R"
        else
            echo "$j finished"
        fi
    done
    return $pending
}

cmd_wait() {
    load_jobs
    local start=$SECONDS last=-1
    while in_queue "$BUILD_JOB" || in_queue "$MPI_JOB"; do
        if [ $((SECONDS - start)) -ge "$WAIT_TIMEOUT" ]; then
            echo "still not finished after ${WAIT_TIMEOUT}s"
            return 2
        fi
        if [ $(((SECONDS - start) / 300)) -ne "$last" ]; then   # one line every 5 minutes
            last=$(((SECONDS - start) / 300))
            squeue -h -j "$BUILD_JOB,$MPI_JOB" -o "  %i %j %T %M reason: %R" 2>/dev/null
        fi
        sleep 30
    done
}

# verdict <name> <jobid>: one line; returns 0 pass, 1 fail, 2 pending.
verdict() {
    local name=$1 job=$2 f="$OUTPUT/$1.status" acct=""
    if [ -f "$f" ] && [ "$(awk '{print $2}' "$f")" = "$job" ]; then
        echo "$name (job $job): $(cut -d' ' -f1,3- "$f")"
        [ "$(awk '{print $1}' "$f")" = PASS ] && return 0
        return 1
    fi
    if in_queue "$job"; then
        echo "$name (job $job): PENDING ($(squeue -h -j "$job" -o '%T, reason: %R'))"
        return 2
    fi
    command -v sacct >/dev/null 2>&1 && acct=$(sacct -j "$job" -X -n -o State,ExitCode 2>/dev/null | xargs)
    echo "$name (job $job): FAIL, ended without a status file [sacct: ${acct:-n/a}]; see $LOGS/qs_${name}_$job.out"
    return 1
}

cmd_report() {
    load_jobs
    local sum=$OUTPUT/summary.txt rc_b rc_m result rc log
    echo "Quicksort test report (submitted $SUBMITTED, project $PROJECT)" > "$sum"
    verdict build_test "$BUILD_JOB" >> "$sum"; rc_b=$?
    verdict mpi_test "$MPI_JOB" >> "$sum"; rc_m=$?
    for log in "$LOGS/build_test_$BUILD_JOB.log" "$LOGS/mpi_test_$MPI_JOB.log"; do
        [ -f "$log" ] || continue
        grep -E '^(FAIL|mpi_smoke:|== mpi_test:)' "$log" | head -30 >> "$sum"
        sed -n '/FAILED  \] [0-9]* tests\{0,1\}, listed below/,/^ *$/p' "$log" | head -30 >> "$sum"
    done
    echo "results CSV: $OUTPUT/mpi_test_$MPI_JOB.csv" >> "$sum"
    if [ $rc_b -eq 0 ] && [ $rc_m -eq 0 ]; then result=PASS rc=0
    elif [ $rc_b -eq 1 ] || [ $rc_m -eq 1 ]; then result=FAIL rc=1
    else result=PENDING rc=2; fi
    echo "RESULT: $result" >> "$sum"
    cat "$sum"
    return $rc
}

cmd_bench() {
    prepare
    local j
    j=$(sbatch "${COMMON[@]}" --nodes="$NODES" "$SRC/speed/job_bench.slurm") || die "sbatch (bench) failed"
    echo "submitted benchmark: job ${j%%;*}"
    echo "results: $OUTPUT/bench_${j%%;*}.csv   log: $LOGS/bench_${j%%;*}.log"
}

case ${1:-all} in
    submit) cmd_submit ;;
    status) cmd_status; exit $? ;;
    wait)   cmd_wait; cmd_report; exit $? ;;
    report) cmd_report; exit $? ;;
    bench)  cmd_bench ;;
    all)    cmd_submit; cmd_wait; cmd_report; exit $? ;;
    -h|--help|help) sed -n '2,30p' "$0" ;;
    *) sed -n '2,30p' "$0"; exit 64 ;;
esac

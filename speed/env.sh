#!/usr/bin/env bash
# Shared settings for the Speed scripts. Sourced, not executed.
#
# Project directory on Speed: staged code, input (run configuration), output
# (CSV, status files, summary), logs and intermediate files (hostfiles).
PROJECT=${PROJECT:-/speed-scratch/$USER/quicksort}
SRC=$PROJECT/src
INPUT=$PROJECT/input
OUTPUT=$PROJECT/output
LOGS=$PROJECT/logs
WORK=$PROJECT/work

# Jobs may land on different CPU models: never build with -march=native here.
export ARCH=${ARCH:-}

# Make `module` available in non-interactive batch shells.
qs_init_modules() {
    if ! command -v module >/dev/null 2>&1; then
        for f in /etc/profile.d/modules.sh /usr/share/Modules/init/bash /etc/profile.d/lmod.sh; do
            # shellcheck disable=SC1090
            [ -f "$f" ] && . "$f" && break
        done
    fi
}

# Newest "openmpi" module, or empty if none.
qs_find_mpi_module() {
    module -t avail 2>&1 | grep -i '^openmpi' | sed 's/(default)//' | sort -V | tail -1 || true
}

# Loads $MODULES (or the newest OpenMPI module). Returns 1 if mpicxx or
# mpirun is still missing afterwards.
qs_load_mpi() {
    qs_init_modules
    if command -v module >/dev/null 2>&1; then
        [ -z "${MODULES:-}" ] && MODULES=$(qs_find_mpi_module)
        if [ -n "${MODULES:-}" ]; then
            # shellcheck disable=SC2086
            module load $MODULES || echo "warning: 'module load $MODULES' failed" >&2
        fi
        export MODULES
    fi
    echo "modules: ${MODULES:-<none>}"
    echo "mpicxx:  $(command -v mpicxx || echo MISSING)"
    echo "mpirun:  $(command -v mpirun || echo MISSING)"
    command -v mpicxx >/dev/null 2>&1 && command -v mpirun >/dev/null 2>&1
}

# OpenMPI hostfile with one slot per allocated node (ranks on distinct nodes).
qs_hostfile() {  # qs_hostfile <path>
    scontrol show hostnames "$SLURM_JOB_NODELIST" | while read -r h; do
        echo "$h slots=1 max_slots=1"
    done > "$1"
}

# Records a job's outcome for run_on_speed.sh: "<PASS|FAIL> <jobid> <message>".
qs_status() {  # qs_status <job-name> PASS|FAIL <message>
    printf '%s %s %s\n' "$2" "${SLURM_JOB_ID:-local}" "$3" > "$OUTPUT/$1.status"
}

#!/usr/bin/env bash
set -euo pipefail

# Generic preflight scaffold. Extend the required tools only after auditing the
# actual pipeline stages; this script is not wired into the existing run_all.sh.

usage() {
  echo "Usage: $0 INPUT_FILE OUTPUT_DIR [required_executable ...]" >&2
}

if (( $# < 2 )); then usage; exit 2; fi
input=$1
outdir=$2
shift 2

if [[ ! -s "$input" ]]; then
  echo "ERROR: input file is missing or empty: $input" >&2
  exit 1
fi

if ! mkdir -p "$outdir"; then
  echo "ERROR: cannot create output directory: $outdir" >&2
  exit 1
fi

for exe in "$@"; do
  if ! command -v "$exe" >/dev/null 2>&1; then
    echo "ERROR: required executable not found on PATH: $exe" >&2
    exit 127
  fi
done

printf 'timestamp\t%s\n' "$(date -Is)"
printf 'input\t%s\n' "$input"
printf 'output_dir\t%s\n' "$outdir"
printf 'host\t%s\n' "$(hostname)"
for exe in "$@"; do
  printf 'executable\t%s\t%s\n' "$exe" "$(command -v "$exe")"
done

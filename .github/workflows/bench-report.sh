#!/bin/bash
# Prints a Markdown table that compares Criterion's `base` baseline with the
# latest run (`new`), with median timings and Criterion's mean-change interval.
#
# Usage: bench-report.sh [criterion dir] [threshold in %]

set -euo pipefail

dir=${1:-target/criterion}
threshold=${2:-10}

# Formats a duration in nanoseconds.
fmt() {
  awk -v ns="$1" 'BEGIN {
    if (ns >= 1e9) printf "%.3f s", ns / 1e9
    else if (ns >= 1e6) printf "%.2f ms", ns / 1e6
    else if (ns >= 1e3) printf "%.2f µs", ns / 1e3
    else printf "%.1f ns", ns
  }'
}

median() {
  jq '.median.point_estimate' "$1"
}

benches=
if [ -d "$dir" ]; then
  benches=$(find "$dir" -path '*/base/estimates.json' -o -path '*/new/estimates.json' |
    sed 's|/[^/]*/estimates.json$||' | sort -u)
fi
if [ -z "$benches" ]; then
  echo "No benchmark results found."
  exit 0
fi

echo "| Benchmark | Base | Head | Mean change |"
echo "| --- | ---: | ---: | ---: |"
while IFS= read -r bench; do
  base="$bench/base/estimates.json"
  new="$bench/new/estimates.json"
  if [ -f "$new" ]; then
    id=$(jq -r '.full_id' "$bench/new/benchmark.json")
  else
    id=$(jq -r '.full_id' "$bench/base/benchmark.json")
  fi
  if [ -f "$base" ] && [ -f "$new" ]; then
    b=$(median "$base")
    h=$(median "$new")
    change="comparison unavailable"
    if [ -f "$bench/change/estimates.json" ]; then
      change=$(jq -er '.mean | [
        .point_estimate,
        .confidence_interval.lower_bound,
        .confidence_interval.upper_bound
      ] | if all(.[]; type == "number") then @tsv else error("Invalid change estimates") end' \
        "$bench/change/estimates.json" |
        awk -v t="$threshold" '{
          mark = $2 * 100 > t ? ":red_circle:" : ($3 * 100 < -t ? ":green_circle:" : "unconfirmed")
          printf "%+.1f%% %s", $1 * 100, mark
        }')
    fi
    echo "| \`$id\` | $(fmt "$b") | $(fmt "$h") | $change |"
  elif [ -f "$new" ]; then
    echo "| \`$id\` | – | $(fmt "$(median "$new")") | new |"
  else
    echo "| \`$id\` | $(fmt "$(median "$base")") | – | removed |"
  fi
done <<<"$benches"

echo
echo "Base and Head show median timings; Mean change compares average timings." \
  ":red_circle: slower or :green_circle: faster by more than ${threshold}%, supported by Criterion's confidence interval." \
  "Unconfirmed means there is insufficient evidence for a change beyond that threshold."

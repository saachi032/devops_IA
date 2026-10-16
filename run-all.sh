#!/bin/bash
# run-all.sh - runs setup, then experiments A, B, C, D, E and the LimitRange bonus.
#
#   ./run-all.sh              run everything without stopping
#   PAUSE=1 ./run-all.sh      stop at screenshot points (press Enter to continue)
#
# Takes roughly 15 to 25 minutes. Output of every step is saved in ./evidence
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE" || exit 1
chmod +x ./*.sh

for step in 00-setup.sh exp-a.sh exp-b.sh exp-c.sh exp-d.sh exp-e.sh exp-f-limitrange.sh; do
  printf '\n\n########## Running %s ##########\n' "$step"
  ./"$step"
  if [ $? -ne 0 ]; then
    printf '\nStopped: %s reported an error. Fix it, then run that script again.\n' "$step"
    exit 1
  fi
done

SUMMARY="$HERE/evidence/SUMMARY.txt"
{
  echo "SUMMARY OF ALL EXPERIMENTS  ($(date))"
  echo "================================================================"
  for f in 00-baseline A-no-limits B-with-limits C-cpu-throttling D-oomkilled E-actual-vs-requested F-limitrange; do
    echo
    echo "[$f]"
    grep '^RESULT:' "$HERE/evidence/$f.txt" 2>/dev/null | sed 's/^RESULT: /  /'
  done
} | tee "$SUMMARY"

printf '\nAll done. Files saved in %s/evidence\n' "$HERE"

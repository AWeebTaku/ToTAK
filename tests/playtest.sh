#!/usr/bin/env bash
# Runs the real-input playtest for several seeds; fails if Godot prints any script error.
set -u
fail=0
for seed in ${SEEDS:-1 2 3 4 5}; do
  # "resources still in use at exit" is a harmless teardown warning from quitting a headless -s run mid-scene
  out=$(SEED=$seed godot --headless -s tests/playtest.gd 2>&1 | grep -v -E "still in use at exit|at: (cleanup|clear) \(")
  echo "$out" | grep -E "playtest ok" || { echo "seed $seed: did not finish"; fail=1; }
  if echo "$out" | grep -E "SCRIPT ERROR|^ERROR|Parse Error|Invalid (call|access)" >/dev/null; then
    echo "seed $seed: errors"; echo "$out" | grep -E -B1 -A6 "SCRIPT ERROR|^ERROR|Invalid (call|access)" | head -40; fail=1
  fi
done
exit $fail

#!/bin/bash
# Experiment C: CPU throttling under load.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
start_log "C-cpu-throttling"

say "EXPERIMENT C: CPU throttling"
preflight
cleanup_workloads

say "Step 1: start a pod that tries to use a full core but has a 200m CPU limit"
run "cat $YAML/05-cpu-limited.yaml"
run "kubectl apply -f $YAML/05-cpu-limited.yaml"
kubectl wait --for=condition=Ready pod/cpu-limited -n "$NS" --timeout=240s
wait_until 300 "metrics for cpu-limited" cpu_at_least cpu-limited 100

say "Step 2: actual usage stays at the limit (6 samples, 5 seconds apart)"
i=1
while [ "$i" -le 6 ]; do
  printf '\n$ kubectl top pod cpu-limited -n %s\n' "$NS"
  kubectl top pod cpu-limited -n "$NS"
  sleep 5
  i=$((i + 1))
done
LIMITED_M="$(cpu_of cpu-limited)"
pause

say "Step 3: kernel proof of throttling (cpu.stat read twice, 10 seconds apart)"
if kubectl exec cpu-limited -n "$NS" -- cat /sys/fs/cgroup/cpu.stat >/dev/null 2>&1; then
  STATFILE=/sys/fs/cgroup/cpu.stat
  note "cgroup v2 detected"
else
  STATFILE=/sys/fs/cgroup/cpu/cpu.stat
  note "cgroup v1 detected"
fi
S1="$(kubectl exec cpu-limited -n "$NS" -- cat "$STATFILE")"
printf '\n$ kubectl exec cpu-limited -n %s -- cat %s   (first reading)\n%s\n' "$NS" "$STATFILE" "$S1"
note "waiting 10 seconds"
sleep 10
S2="$(kubectl exec cpu-limited -n "$NS" -- cat "$STATFILE")"
printf '\n$ kubectl exec cpu-limited -n %s -- cat %s   (second reading)\n%s\n' "$NS" "$STATFILE" "$S2"

val() { echo "$1" | awk -v k="$2" '$1==k{print $2}'; }
P1="$(val "$S1" nr_periods)";   P2="$(val "$S2" nr_periods)"
T1="$(val "$S1" nr_throttled)"; T2="$(val "$S2" nr_throttled)"
DP=$(( P2 - P1 )); DT=$(( T2 - T1 ))
if [ "$DP" -gt 0 ]; then PCT=$(( DT * 100 / DP )); else PCT=0; fi
printf '\nBetween the two readings: nr_periods +%s, nr_throttled +%s  =>  throttled in about %s%% of periods\n' "$DP" "$DT" "$PCT"
pause

say "Step 4: compare with a pod that has NO limit"
run "cat $YAML/06-cpu-unlimited.yaml"
run "kubectl apply -f $YAML/06-cpu-unlimited.yaml"
kubectl wait --for=condition=Ready pod/cpu-unlimited -n "$NS" --timeout=240s
wait_until 300 "metrics for cpu-unlimited" cpu_at_least cpu-unlimited 300
sleep 15
run "kubectl top pod -n $NS"
UNLIMITED_M="$(cpu_of cpu-unlimited)"
pause

result "cpu-limited used about ${LIMITED_M}m against a 200m limit and was throttled in about ${PCT}% of scheduling periods (nr_throttled rose by ${DT}). The same loop with no limit used about ${UNLIMITED_M}m. CPU limits slow a pod down; they do not kill it."

cleanup_workloads
finish

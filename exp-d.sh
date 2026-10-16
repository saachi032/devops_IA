#!/bin/bash
# Experiment D: OOMKilled when a pod exceeds its memory limit.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
start_log "D-oomkilled"

say "EXPERIMENT D: exceeding the memory limit (OOMKilled)"
preflight
cleanup_workloads

SAMPLES="$EVID/D-memory-samples.txt"
SAMPLER=""
trap '[ -n "$SAMPLER" ] && kill "$SAMPLER" 2>/dev/null' EXIT

say "Step 1: start a pod that keeps growing its memory (limit is 100Mi)"
run "cat $YAML/07-oom.yaml"
run "kubectl apply -f $YAML/07-oom.yaml"

# Record kubectl top every 5 seconds in the background while the pod grows.
: > "$SAMPLES"
( while true; do
    out="$(kubectl top pod oom-demo -n "$NS" --no-headers 2>/dev/null)"
    [ -n "$out" ] && echo "$(date +%H:%M:%S)  $out" >> "$SAMPLES"
    sleep 5
  done ) &
SAMPLER=$!

say "Step 2: watching the pod until it is killed (this takes 1 to 3 minutes)"
waited=0
while ! pod_reason_oom; do
  printf '%s  %s\n' "$(date +%H:%M:%S)" "$(kubectl get pod oom-demo -n "$NS" --no-headers 2>/dev/null)"
  sleep 5
  waited=$((waited + 5))
  if [ "$waited" -ge 420 ]; then
    note "Timed out waiting for OOMKilled. Run the script again."
    break
  fi
done

if pod_reason_oom; then
  note "OOMKilled seen. Watching the restart for 40 more seconds"
  end=$(( $(date +%s) + 40 ))
  while [ "$(date +%s)" -lt "$end" ]; do
    printf '%s  %s\n' "$(date +%H:%M:%S)" "$(kubectl get pod oom-demo -n "$NS" --no-headers 2>/dev/null)"
    sleep 5
  done
fi
kill "$SAMPLER" 2>/dev/null; SAMPLER=""
pause

say "Step 3: memory readings taken by kubectl top while it grew"
cat "$SAMPLES"
PEAK="$(awk '{v=$4; sub(/Mi/,"",v); if (v+0>m) m=v+0} END{print m+0}' "$SAMPLES")"
pause

say "Step 4: why was it killed?"
run "kubectl describe pod oom-demo -n $NS | grep -A 10 'Last State'"
run "kubectl get events -n $NS --sort-by=.lastTimestamp | tail -10"
run "kubectl logs oom-demo -n $NS --tail=5"
REASON="$(kubectl get pod oom-demo -n "$NS" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)"
CODE="$(kubectl get pod oom-demo -n "$NS" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}' 2>/dev/null)"
RESTARTS="$(kubectl get pod oom-demo -n "$NS" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)"
pause

kubectl describe pod oom-demo -n "$NS" > "$EVID/D-oom-describe.txt"

result "memory climbed to a peak reading of about ${PEAK}Mi against a 100Mi limit. Last State: reason ${REASON}, exit code ${CODE}, restarts ${RESTARTS}. Kubernetes restarted the container, which is why memory dropped back and grew again."

cleanup_workloads
finish

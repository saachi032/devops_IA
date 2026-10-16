#!/bin/bash
# Experiment A: pods with NO requests or limits.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
start_log "A-no-limits"

say "EXPERIMENT A: pods with no requests or limits"
preflight
cleanup_workloads

BASE_M="$(node_req_cpu_m)"
note "Baseline: CPU already reserved on the node by system pods = ${BASE_M}m"
run "kubectl describe node $NODE | grep -A 8 'Allocated resources'"
pause

say "Step 1: deploy 5 pods that have no resources section"
run "cat $YAML/02-no-limits.yaml"
run "kubectl apply -f $YAML/02-no-limits.yaml"
kubectl rollout status deployment/web-no-limits -n "$NS" --timeout=240s
run "kubectl get pods -n $NS -o wide"
pause

say "Step 2: what did the scheduler reserve for them?"
run "kubectl describe node $NODE | grep -A 25 'Non-terminated Pods'"
run "kubectl describe node $NODE | grep -A 8 'Allocated resources'"
AFTER5_M="$(node_req_cpu_m)"
pause

say "Step 3: Quality of Service class of these pods"
run "kubectl get pods -n $NS -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass"
pause

say "Step 4: what are they actually using?"
wait_until 240 "metrics for the pods" kubectl top pod -n "$NS"
run "kubectl top pod -n $NS"
pause

say "Step 5: overcommit the node by scaling to 30 pods"
run "kubectl scale deployment web-no-limits -n $NS --replicas=30"
wait_until 300 "all 30 pods to be Running" all_running 30
printf '\nRunning pods: %s\n' "$(running_count)"
run "kubectl describe node $NODE | grep -A 8 'Allocated resources'"
AFTER30_M="$(node_req_cpu_m)"
pause

result "baseline ${BASE_M}m, with 5 pods ${AFTER5_M}m, with 30 pods ${AFTER30_M}m of CPU reserved. $(running_count) pods running, all BestEffort. The scheduler reserved nothing, so it accepted every pod."

kubectl describe node "$NODE" > "$EVID/A-node-no-limits.txt"
cleanup_workloads
finish

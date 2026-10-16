#!/bin/bash
# Experiment B: pods WITH requests and limits, scheduler placement, Pending pods.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
start_log "B-with-limits"

say "EXPERIMENT B: pods with requests and limits"
preflight
cleanup_workloads

BASE_M="$(node_req_cpu_m)"
note "Baseline CPU reserved by system pods = ${BASE_M}m"

say "Step 1: deploy 3 pods (each requests 200m CPU / 64Mi, limit 500m CPU / 128Mi)"
run "cat $YAML/03-with-limits.yaml"
run "kubectl apply -f $YAML/03-with-limits.yaml"
kubectl rollout status deployment/web-with-limits -n "$NS" --timeout=240s
run "kubectl get pods -n $NS -o wide"
pause

say "Step 2: the node now reserves resources for them"
run "kubectl describe node $NODE | grep -A 25 'Non-terminated Pods'"
run "kubectl describe node $NODE | grep -A 8 'Allocated resources'"
AFTER3_M="$(node_req_cpu_m)"
pause

say "Step 3: Quality of Service class"
run "kubectl get pods -n $NS -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass"
pause

say "Step 4: fill the node so some pods cannot be placed"
ALLOC_M="$(node_alloc_cpu_m)"
EXTRA=$(( (ALLOC_M - AFTER3_M) / 200 ))
[ "$EXTRA" -lt 0 ] && EXTRA=0
TARGET=$(( 3 + EXTRA + 10 ))
note "Node can reserve ${ALLOC_M}m, already ${AFTER3_M}m used, so about ${EXTRA} more pods fit. Scaling to ${TARGET} so that about 10 cannot be placed."
run "kubectl scale deployment web-with-limits -n $NS --replicas=$TARGET"
wait_until 120 "the scheduler to refuse some pods" some_unsched
wait_until 240 "the pods to settle" settled "$TARGET"
sleep 5
run "kubectl get pods -n $NS"
pause

say "Step 5: why are some pods Pending? (scheduler message)"
PENDING="$(kubectl get pods -n "$NS" --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ -n "$PENDING" ]; then
  run "kubectl describe pod $PENDING -n $NS | tail -8"
  run "kubectl get events -n $NS --sort-by=.lastTimestamp | grep FailedScheduling | tail -3"
else
  note "No Pending pod found. Try running the script again."
fi
pause

say "Step 6: node reservation versus real usage"
run "kubectl describe node $NODE | grep -A 8 'Allocated resources'"
wait_until 180 "node metrics" kubectl top node
run "kubectl top node"
RUN_NOW="$(running_count)"
PEND_NOW="$(unsched_count)"
FULL_M="$(node_req_cpu_m)"
REAL="$(kubectl top node --no-headers | awk '{print $2" ("$3")"}')"
pause

say "Step 7: scale back down"
run "kubectl scale deployment web-with-limits -n $NS --replicas=3"
kubectl describe node "$NODE" > "$EVID/B-node-with-limits.txt"

say "Step 8: Guaranteed class (requests equal limits)"
run "cat $YAML/04-guaranteed.yaml"
run "kubectl apply -f $YAML/04-guaranteed.yaml"
kubectl wait --for=condition=Ready pod/guaranteed-pod -n "$NS" --timeout=180s
run "kubectl get pods -n $NS -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass"
pause

result "3 pods raised the reservation from ${BASE_M}m to ${AFTER3_M}m CPU. At ${TARGET} replicas, ${RUN_NOW} pods ran and ${PEND_NOW} stayed Pending (Insufficient cpu). Reserved ${FULL_M}m of ${ALLOC_M}m, but real node usage was ${REAL}. Classes seen: Burstable and Guaranteed."

cleanup_workloads
finish

#!/bin/bash
# Bonus: LimitRange gives default requests and limits to pods that declare none.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
start_log "F-limitrange"

say "BONUS: LimitRange defaults"
preflight
cleanup_workloads

run "cat $YAML/08-limitrange.yaml"
run "kubectl apply -f $YAML/08-limitrange.yaml"

say "Create a pod with NO resources section"
run "kubectl run test-default --image=nginx:1.27-alpine -n $NS"
kubectl wait --for=condition=Ready pod/test-default -n "$NS" --timeout=240s

say "What did Kubernetes give it?"
run "kubectl get pod test-default -n $NS -o jsonpath='{.spec.containers[0].resources}'"
echo
run "kubectl get pod test-default -n $NS -o jsonpath='{.status.qosClass}'"
echo
RES="$(kubectl get pod test-default -n "$NS" -o jsonpath='{.spec.containers[0].resources}')"
QOS="$(kubectl get pod test-default -n "$NS" -o jsonpath='{.status.qosClass}')"
pause

result "a pod created with no resources section received defaults automatically: ${RES}, QoS ${QOS}."

cleanup_workloads
finish

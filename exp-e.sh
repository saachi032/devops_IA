#!/bin/bash
# Experiment E: actual usage versus requested and limited.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
start_log "E-actual-vs-requested"

say "EXPERIMENT E: actual usage versus requested and limited"
preflight
cleanup_workloads

say "Step 1: run 3 nginx pods with requests/limits plus the 200m-limited CPU burner"
run "kubectl apply -f $YAML/03-with-limits.yaml"
run "kubectl apply -f $YAML/05-cpu-limited.yaml"
kubectl rollout status deployment/web-with-limits -n "$NS" --timeout=240s
kubectl wait --for=condition=Ready pod/cpu-limited -n "$NS" --timeout=240s
wait_until 300 "metrics for every pod" top_lines_at_least 4
wait_until 300 "cpu-limited to reach its limit" cpu_at_least cpu-limited 150
sleep 15
pause

say "Step 2: the combined view"
chmod +x "$ROOT/compare.sh"
"$ROOT/compare.sh" | tee "$EVID/E-compare.txt"

LIM="$(cpu_of cpu-limited)"
NODEUSE="$(kubectl top node --no-headers | awk '{print $2" CPU ("$3"), "$4" memory ("$5")"}')"
RES_M="$(node_req_cpu_m)"
pause

result "three numbers exist for every pod. nginx pods requested 200m but used about 0m. cpu-limited had a 200m limit and used about ${LIM}m. The node had ${RES_M}m of CPU reserved by requests but real use was only ${NODEUSE}."

cleanup_workloads
finish

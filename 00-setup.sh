#!/bin/bash
# 00-setup.sh - run once after installing Docker Desktop, kubectl and minikube.
# Starts the cluster (if needed), enables metrics-server, waits until
# "kubectl top" works, creates the namespace, and records the empty-cluster baseline.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
start_log "00-baseline"

say "SETUP: cluster, metrics-server and baseline"
preflight

run "kubectl get nodes"
run "kubectl top nodes"
run "kubectl describe node $NODE | grep -A 6 'Allocatable'"
run "kubectl describe node $NODE | grep -A 8 'Allocated resources'"

result "cluster ready. CPU available to pods: $(node_alloc_cpu_m)m. Already reserved by system pods: $(node_req_cpu_m)m."
pause
finish

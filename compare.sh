#!/bin/bash
NS=resource-demo
echo "=== REQUESTED AND LIMITED (from the YAML) ==="
kubectl get pods -n $NS -o custom-columns='NAME:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,CPU_LIM:.spec.containers[0].resources.limits.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,MEM_LIM:.spec.containers[0].resources.limits.memory'
echo
echo "=== ACTUAL USAGE (kubectl top pod) ==="
kubectl top pod -n $NS
echo
echo "=== NODE USAGE (kubectl top node) ==="
kubectl top node
echo
echo "=== NODE RESERVATIONS (describe node) ==="
kubectl describe node minikube | grep -A 8 "Allocated resources"

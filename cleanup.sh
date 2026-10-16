#!/bin/bash
# cleanup.sh - remove the experiment namespace. Add "stop" to also stop the cluster
# (frees the RAM), or "delete" to remove the cluster completely.
#   ./cleanup.sh
#   ./cleanup.sh stop
#   ./cleanup.sh delete
kubectl delete namespace resource-demo --ignore-not-found
case "$1" in
  stop)   minikube stop ;;
  delete) minikube delete --all ;;
esac
echo "Done. To free RAM, also quit Docker Desktop from the menu bar."

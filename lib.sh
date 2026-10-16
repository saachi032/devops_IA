#!/bin/bash
# lib.sh - shared helpers for all experiment scripts.
# Works with the bash that ships with macOS (3.2). Do not run this file directly.

NS=resource-demo
NODE=minikube
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YAML="$ROOT/yaml"
EVID="$ROOT/evidence"
mkdir -p "$EVID"

# PAUSE=1 makes each script stop at key points so you can take a screenshot.
PAUSE="${PAUSE:-0}"

say()  { printf '\n==================================================\n%s\n==================================================\n' "$*"; }
note() { printf '\n--> %s\n' "$*"; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

# Print a command the way a terminal would, then run it.
run() { printf '\n$ %s\n' "$*"; eval "$*"; }

pause() {
  if [ "$PAUSE" = "1" ]; then
    printf '\n[Screenshot point. Press Enter to continue] '
    read -r _
  fi
}

# Save everything this script prints into evidence/<name>.txt as well as the screen.
start_log() {
  LOGFILE="$EVID/$1.txt"
  exec > >(tee "$LOGFILE") 2>&1
  printf 'Log started %s\n' "$(date)"
}
finish() {
  printf '\nSaved a copy of this output to: %s\n' "$LOGFILE"
  sleep 1
}

# wait_until <timeout seconds> <description> <command...>
# Re-runs the command every 5 seconds until it succeeds or the timeout passes.
wait_until() {
  local timeout="$1" desc="$2"; shift 2
  local waited=0
  printf 'Waiting for %s ' "$desc"
  while ! "$@" >/dev/null 2>&1; do
    sleep 5
    waited=$((waited + 5))
    printf '.'
    if [ "$waited" -ge "$timeout" ]; then
      printf ' TIMED OUT after %ss\n' "$timeout"
      return 1
    fi
  done
  printf ' done (%ss)\n' "$waited"
  return 0
}

# ---- numbers from the cluster -------------------------------------------

# "950m" -> 950, "4" -> 4000, "1.5" -> 1500
to_m() {
  case "$1" in
    *m) echo "${1%m}" ;;
    *)  awk -v v="$1" 'BEGIN{printf "%d", v*1000}' ;;
  esac
}

node_alloc_cpu_m() {
  to_m "$(kubectl get node "$NODE" -o jsonpath='{.status.allocatable.cpu}')"
}

# CPU requests already reserved on the node, in millicores (from describe node)
node_req_cpu_m() {
  to_m "$(kubectl describe node "$NODE" | awk '/^Allocated resources:/{f=1} f && $1=="cpu"{print $2; exit}')"
}

running_count() {
  kubectl get pods -n "$NS" --no-headers 2>/dev/null | awk '$3=="Running"{c++} END{print c+0}'
}

# pods the scheduler has refused (PodScheduled = False)
unsched_count() {
  kubectl get pods -n "$NS" -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="PodScheduled")].status}{"\n"}{end}' 2>/dev/null \
    | awk '$1=="False"{c++} END{print c+0}'
}

all_running()   { [ "$(running_count)" -ge "$1" ]; }
some_unsched()  { [ "$(unsched_count)" -ge 1 ]; }
settled()       { [ $(( $(running_count) + $(unsched_count) )) -ge "$1" ]; }

# CPU of a pod in millicores, empty if metrics are not there yet
cpu_of() {
  local v
  v="$(kubectl top pod "$1" -n "$NS" --no-headers 2>/dev/null | awk '{print $2}')"
  [ -n "$v" ] && to_m "$v"
}
cpu_at_least() {
  local m
  m="$(cpu_of "$1")"
  [ -n "$m" ] && [ "$m" -ge "$2" ]
}
pod_reason_oom() {
  [ "$(kubectl get pod oom-demo -n "$NS" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)" = "OOMKilled" ]
}
top_lines_at_least() {
  [ "$(kubectl top pod -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')" -ge "$1" ]
}

# ---- setup and cleanup ----------------------------------------------------

preflight() {
  command -v kubectl  >/dev/null 2>&1 || die "kubectl not found. Install it with: brew install kubectl"
  command -v minikube >/dev/null 2>&1 || die "minikube not found. Install it with: brew install minikube"
  docker info >/dev/null 2>&1 || die "Docker Desktop is not running. Open it, wait for the engine to start, and try again."

  if ! minikube status 2>/dev/null | grep -q "host: Running"; then
    note "Cluster is not running. Starting minikube (first time can take several minutes)"
    minikube start --driver=docker --cpus=2 --memory=3072 || die "minikube failed to start"
  fi

  wait_until 180 "the node to be Ready" kubectl wait --for=condition=Ready "node/$NODE" --timeout=5s || die "Node never became Ready"

  minikube addons enable metrics-server >/dev/null 2>&1
  wait_until 240 "metrics-server to be available" kubectl -n kube-system rollout status deployment/metrics-server --timeout=5s || die "metrics-server did not start"
  wait_until 300 "kubectl top node to return numbers" kubectl top node || die "Metrics API never became available. Wait a minute and run the script again."

  kubectl apply -f "$YAML/01-namespace.yaml" >/dev/null
}

# Remove everything from earlier experiments so each one starts clean.
cleanup_workloads() {
  kubectl delete deployment,pod,limitrange --all -n "$NS" --ignore-not-found --grace-period=1 >/dev/null 2>&1
  local waited=0
  while [ "$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; do
    sleep 3; waited=$((waited + 3))
    [ "$waited" -ge 120 ] && break
  done
}

result() { printf '\nRESULT: %s\n' "$*"; }

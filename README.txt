KUBERNETES REQUESTS AND LIMITS - AUTOMATED EXPERIMENTS

Run after installing Docker Desktop, kubectl and minikube
(brew install --cask docker ; brew install kubectl minikube).
Docker Desktop must be open and running.

FIRST TIME ONLY (in Terminal, inside this folder):
  chmod +x *.sh

RUN EVERYTHING:
  ./run-all.sh               runs all experiments back to back
  PAUSE=1 ./run-all.sh       same, but stops at screenshot points

RUN ONE EXPERIMENT (each one prepares the cluster by itself):
  ./00-setup.sh              start cluster, enable metrics-server, record baseline
  ./exp-a.sh                 A: no requests or limits (default scheduling)
  ./exp-b.sh                 B: requests and limits, Pending pods, QoS classes
  ./exp-c.sh                 C: CPU throttling
  ./exp-d.sh                 D: OOMKilled
  ./exp-e.sh                 E: actual versus requested and limited
  ./exp-f-limitrange.sh      Bonus: LimitRange defaults

EVIDENCE:
  Everything printed is also saved in ./evidence
  (A-no-limits.txt, B-with-limits.txt, C-cpu-throttling.txt, D-oomkilled.txt,
   E-actual-vs-requested.txt, F-limitrange.txt, SUMMARY.txt and more).
  Use PAUSE=1 and take screenshots of the terminal at each pause.

CLEAN UP:
  ./cleanup.sh               remove the experiment namespace
  ./cleanup.sh stop          also stop minikube (frees RAM)
  ./cleanup.sh delete        also delete the cluster

The yaml folder holds the same 8 YAML files used in the report.
Each experiment deletes its own pods at the end, so they can be run in any order.

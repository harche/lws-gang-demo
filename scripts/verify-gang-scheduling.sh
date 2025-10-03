#!/bin/bash
echo "=== 1. Check PodGroups created by LeaderWorkerSet ==="
echo "This proves LWS is creating Volcano PodGroups for gang scheduling:"
kubectl get podgroups -n gang-demo
echo ""

echo "=== 2. Show PodGroup details with minMember requirement ==="
echo "minMember: 4 means all 4 pods must be scheduled together:"
kubectl get podgroup -n gang-demo gang-constrained-0-6958bb5cd9 -o jsonpath='{.spec.minMember}' 2>/dev/null || echo "PodGroup details:"
kubectl describe podgroup -n gang-demo | grep -A 5 "Min Member"
echo ""

echo "=== 3. Check pod status - with gang scheduling, if not all can schedule, NONE should be Running ==="
kubectl get pods -n gang-demo -l leaderworkerset.sigs.k8s.io/name=gang-constrained
echo ""

echo "=== 4. Show PodGroup events - look for 'Unschedulable' events ==="
kubectl get events -n gang-demo --field-selector involvedObject.kind=PodGroup --sort-by='.lastTimestamp' | tail -10
echo ""

echo "=== 5. Check available nodes (2 are tainted, only worker3 available) ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
echo ""

echo "=== 6. Show PodGroup status ==="
kubectl get podgroups -n gang-demo -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,MIN:.spec.minMember,RUNNING:.status.running

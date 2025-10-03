#!/bin/bash
set -e

echo "===================================================="
echo "LeaderWorkerSet Gang Scheduling Demo"
echo "===================================================="
echo ""

# Create namespace
echo "📝 Creating demo namespace..."
kubectl create namespace gang-demo --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"
echo ""

# Demo 1: Basic gang scheduling
echo "===================================================="
echo "Demo 1: Basic Gang Scheduling"
echo "===================================================="
echo ""
echo "Deploying LeaderWorkerSet with 4 pods (1 leader + 3 workers)..."
kubectl apply -f manifests/examples/gang-test.yaml
sleep 5

echo ""
echo "🔍 Checking PodGroups created:"
kubectl get podgroups -n gang-demo
echo ""

echo "🔍 Checking pod status:"
kubectl get pods -n gang-demo -l leaderworkerset.sigs.k8s.io/name=gang-test
echo ""

echo "✅ All pods should be Running (gang scheduled together)"
echo ""
read -p "Press Enter to continue to Demo 2..."

# Demo 2: Resource-constrained scenario
echo ""
echo "===================================================="
echo "Demo 2: Gang Scheduling Under Resource Constraints"
echo "===================================================="
echo ""
echo "Tainting 2 worker nodes to simulate limited resources..."
kubectl taint nodes llm-d-demo-worker test=blocked:NoSchedule --overwrite
kubectl taint nodes llm-d-demo-worker2 test=blocked:NoSchedule --overwrite
echo "✅ Nodes tainted"
echo ""

echo "Deploying resource-constrained LeaderWorkerSet (requires 2 nodes, only 1 available)..."
kubectl apply -f manifests/examples/gang-constrained.yaml
sleep 10

echo ""
echo "🔍 Checking PodGroup status:"
kubectl get podgroups -n gang-demo -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,MIN:.spec.minMember,RUNNING:.status.running
echo ""

echo "🔍 Checking pod status:"
kubectl get pods -n gang-demo -l leaderworkerset.sigs.k8s.io/name=gang-constrained
echo ""

echo "✅ All pods should be Pending (gang scheduler preventing partial deployment)"
echo ""
echo "🔍 PodGroup events:"
kubectl get events -n gang-demo --field-selector involvedObject.kind=PodGroup | grep gang-constrained | tail -3
echo ""
read -p "Press Enter to make resources available..."

# Make resources available
echo ""
echo "Removing taint from worker2 to make resources available..."
kubectl taint nodes llm-d-demo-worker2 test=blocked:NoSchedule-
echo "✅ Resources available"
echo ""

echo "⏳ Waiting for gang scheduling to schedule all pods..."
sleep 10

echo ""
echo "🔍 Checking pod status after resource availability:"
kubectl get pods -n gang-demo -l leaderworkerset.sigs.k8s.io/name=gang-constrained
echo ""

echo "✅ All pods should now be Running (scheduled atomically together)"
echo ""
read -p "Press Enter to continue to Demo 3..."

# Demo 3: Comparison without gang scheduling
echo ""
echo "===================================================="
echo "Demo 3: Comparison WITHOUT Gang Scheduling"
echo "===================================================="
echo ""
echo "Re-applying resource constraints..."
kubectl taint nodes llm-d-demo-worker2 test=blocked:NoSchedule --overwrite
echo "✅ Constraints applied"
echo ""

echo "Deploying regular Deployment (no gang scheduling, using default scheduler)..."
kubectl apply -f manifests/examples/no-gang.yaml
sleep 5

echo ""
echo "🔍 Checking pod status (default scheduler):"
kubectl get pods -n gang-demo -l app=no-gang
echo ""

echo "❌ Notice: PARTIAL DEPLOYMENT! Some pods Running, some Pending"
echo "   This is the resource deadlock problem RHOAISTRAT-652 describes!"
echo ""

echo "🔍 Compare with gang-scheduled pods:"
kubectl get pods -n gang-demo -l leaderworkerset.sigs.k8s.io/name=gang-constrained
echo ""
echo "✅ Gang-scheduled pods: ALL Pending (no partial deployment)"
echo ""

# Summary
echo ""
echo "===================================================="
echo "📊 Demo Summary"
echo "===================================================="
echo ""
echo "Gang Scheduling Benefits Demonstrated:"
echo "1. ✅ PodGroups automatically created by LeaderWorkerSet"
echo "2. ✅ All-or-nothing scheduling (no partial deployments)"
echo "3. ✅ Atomic scheduling when resources available"
echo "4. ✅ Prevents resource deadlocks in distributed workloads"
echo ""
echo "Key Difference:"
echo "- WITH gang scheduling: 0 pods running OR all pods running"
echo "- WITHOUT gang scheduling: Partial deployment (some running, some pending)"
echo ""
echo "Run './scripts/verify-gang-scheduling.sh' for detailed verification"
echo ""

# Cleanup option
read -p "Do you want to cleanup the demo? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧹 Cleaning up..."
    kubectl delete namespace gang-demo
    kubectl taint nodes llm-d-demo-worker test=blocked:NoSchedule- --ignore-not-found
    kubectl taint nodes llm-d-demo-worker2 test=blocked:NoSchedule- --ignore-not-found
    echo "✅ Cleanup complete"
fi

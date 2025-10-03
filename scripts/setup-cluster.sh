#!/bin/bash
set -e

echo "===================================================="
echo "LeaderWorkerSet Gang Scheduling Demo - Setup Script"
echo "===================================================="
echo ""

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo "❌ Error: kind is not installed"
    echo "Please install kind: https://kind.sigs.k8s.io/docs/user/quick-start/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Step 1: Create kind cluster
echo "📦 Step 1: Creating kind cluster with 3 worker nodes..."
kind create cluster --name lws-gang-demo --config manifests/setup/kind-config.yaml
echo "✅ Cluster created"
echo ""

# Step 2: Install Volcano
echo "🌋 Step 2: Installing Volcano scheduler..."
kubectl apply -f https://raw.githubusercontent.com/volcano-sh/volcano/master/installer/volcano-development.yaml
echo "⏳ Waiting for Volcano to be ready..."
kubectl wait --for=condition=ready pod -l app=volcano-admission -n volcano-system --timeout=120s
echo "✅ Volcano installed"
echo ""

# Step 3: Install LeaderWorkerSet
echo "👥 Step 3: Installing LeaderWorkerSet v0.7.0..."
kubectl apply --server-side -f https://github.com/kubernetes-sigs/lws/releases/download/v0.7.0/manifests.yaml
echo "⏳ Waiting for LWS controller to be ready..."
kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n lws-system --timeout=120s
echo "✅ LeaderWorkerSet installed"
echo ""

# Step 4: Configure gang scheduling
echo "⚙️  Step 4: Configuring gang scheduling..."
kubectl patch configmap lws-manager-config -n lws-system --type merge -p '{
  "data": {
    "controller_manager_config.yaml": "apiVersion: config.lws.x-k8s.io/v1alpha1\nkind: Configuration\nleaderElection:\n  leaderElect: true\ninternalCertManagement:\n  enable: true\ngangSchedulingManagement:\n  schedulerProvider: volcano\n"
  }
}'
echo "✅ Gang scheduling configuration applied"
echo ""

# Step 5: Apply Volcano RBAC
echo "🔐 Step 5: Applying Volcano RBAC for LWS..."
kubectl apply -f manifests/setup/volcano-rbac.yaml
echo "✅ RBAC configured"
echo ""

# Step 6: Restart LWS controller
echo "🔄 Step 6: Restarting LWS controller to apply changes..."
kubectl rollout restart deployment lws-controller-manager -n lws-system
kubectl rollout status deployment lws-controller-manager -n lws-system --timeout=120s
echo "✅ LWS controller restarted"
echo ""

echo "===================================================="
echo "✅ Setup complete!"
echo "===================================================="
echo ""
echo "Next steps:"
echo "1. Create a namespace for testing:"
echo "   kubectl create namespace gang-demo"
echo ""
echo "2. Deploy a LeaderWorkerSet with gang scheduling:"
echo "   kubectl apply -f manifests/examples/gang-test.yaml"
echo ""
echo "3. Verify gang scheduling is working:"
echo "   ./scripts/verify-gang-scheduling.sh"
echo ""
echo "4. Run the full demo:"
echo "   ./scripts/run-demo.sh"
echo ""

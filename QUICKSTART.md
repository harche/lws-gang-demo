# Quick Start Guide

Get up and running with LeaderWorkerSet gang scheduling in 5 minutes!

## Prerequisites

- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- Docker running

## Installation

### Option 1: Automated Setup (Recommended)

```bash
# Clone the repository
git clone https://github.com/harche/lws-gang-demo.git
cd lws-gang-demo

# Run automated setup (creates cluster + installs everything)
./scripts/setup-cluster.sh
```

### Option 2: Manual Setup

```bash
# 1. Create kind cluster
kind create cluster --name lws-gang-demo --config manifests/setup/kind-config.yaml

# 2. Install Volcano
kubectl apply -f https://raw.githubusercontent.com/volcano-sh/volcano/master/installer/volcano-development.yaml
kubectl wait --for=condition=ready pod -l app=volcano-admission -n volcano-system --timeout=120s

# 3. Install LeaderWorkerSet
kubectl apply --server-side -f https://github.com/kubernetes-sigs/lws/releases/download/v0.7.0/manifests.yaml
kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n lws-system --timeout=120s

# 4. Enable gang scheduling
kubectl patch configmap lws-manager-config -n lws-system --type merge -p '{
  "data": {
    "controller_manager_config.yaml": "apiVersion: config.lws.x-k8s.io/v1alpha1\nkind: Configuration\nleaderElection:\n  leaderElect: true\ninternalCertManagement:\n  enable: true\ngangSchedulingManagement:\n  schedulerProvider: volcano\n"
  }
}'

# 5. Apply RBAC
kubectl apply -f manifests/setup/volcano-rbac.yaml

# 6. Restart controller
kubectl rollout restart deployment lws-controller-manager -n lws-system
kubectl rollout status deployment lws-controller-manager -n lws-system --timeout=120s
```

## Running the Demo

### Interactive Demo

```bash
./scripts/run-demo.sh
```

This will walk you through:
1. ✅ Basic gang scheduling
2. ✅ Resource-constrained scenario
3. ✅ Comparison with non-gang scheduling

### Manual Exploration

```bash
# Create namespace
kubectl create namespace gang-demo

# Deploy LeaderWorkerSet with gang scheduling
kubectl apply -f manifests/examples/gang-test.yaml

# Check PodGroups
kubectl get podgroups -n gang-demo

# Check pods
kubectl get pods -n gang-demo

# Verify gang scheduling behavior
./scripts/verify-gang-scheduling.sh
```

## Verification

Run the verification script to see gang scheduling in action:

```bash
./scripts/verify-gang-scheduling.sh
```

Expected output:
- ✅ PodGroups created with minMember requirements
- ✅ All-or-nothing pod scheduling
- ✅ Events showing gang scheduling behavior

## Key Commands

```bash
# View PodGroups
kubectl get podgroups -n gang-demo

# Describe PodGroup
kubectl describe podgroup <podgroup-name> -n gang-demo

# View PodGroup events
kubectl get events -n gang-demo --field-selector involvedObject.kind=PodGroup

# Check pod scheduler
kubectl get pods -n gang-demo -o custom-columns=NAME:.metadata.name,SCHEDULER:.spec.schedulerName
```

## Cleanup

```bash
# Delete demo namespace
kubectl delete namespace gang-demo

# Delete entire cluster
./scripts/cleanup.sh
# OR
kind delete cluster --name lws-gang-demo
```

## What's Happening?

1. **LeaderWorkerSet controller** creates:
   - Leader and worker pods (with `schedulerName: volcano`)
   - Volcano PodGroup (with `minMember: 4`)

2. **Volcano scheduler**:
   - Waits until ALL 4 pods can be scheduled
   - Schedules them atomically (all-or-nothing)
   - Prevents partial deployments

3. **Result**: No resource deadlocks in distributed workloads!

## Examples

| File | Description |
|------|-------------|
| `manifests/examples/gang-test.yaml` | Basic LeaderWorkerSet with gang scheduling |
| `manifests/examples/gang-constrained.yaml` | Resource-constrained scenario |
| `manifests/examples/no-gang.yaml` | Deployment without gang scheduling (for comparison) |

## Troubleshooting

**PodGroups not created?**
- Check LWS config: `kubectl get cm lws-manager-config -n lws-system -o yaml`
- Ensure `gangSchedulingManagement.schedulerProvider: volcano` is set

**Pods not scheduling?**
- Check PodGroup status: `kubectl get podgroups -n gang-demo`
- View events: `kubectl get events -n gang-demo`

**Permission errors?**
- Apply RBAC: `kubectl apply -f manifests/setup/volcano-rbac.yaml`

## Next Steps

- Read the full [test report](README.md) for detailed analysis
- Explore [architecture documentation](docs/architecture.md)
- Try modifying replica counts and resource requirements
- Test with actual workloads (vLLM, etc.)

## Reference

- [LeaderWorkerSet](https://github.com/kubernetes-sigs/lws)
- [Volcano Scheduler](https://github.com/volcano-sh/volcano)
- [Gang Scheduling KEP](https://github.com/kubernetes-sigs/lws/tree/main/keps/407-gang-scheduling)
- [RHOAISTRAT-652](https://issues.redhat.com/browse/RHOAISTRAT-652)

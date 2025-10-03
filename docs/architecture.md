# Division of Responsibilities: LWS vs Volcano

## LeaderWorkerSet Controller (LWS)
**Type:** Kubernetes Workload Controller
**Repo:** kubernetes-sigs/lws

### Responsibilities:
1. ✅ Watch LeaderWorkerSet resources
2. ✅ Create leader and worker pods
3. ✅ **Create Volcano PodGroup resources** (when gangSchedulingManagement.schedulerProvider=volcano)
4. ✅ Calculate minMember (based on size)
5. ✅ Calculate minResources (sum of pod requests)
6. ✅ Manage PodGroup lifecycle

### Does NOT do:
- ❌ Schedule pods
- ❌ Make scheduling decisions
- ❌ Implement gang scheduling logic
- ❌ Wait for resources
- ❌ Perform all-or-nothing binding

## Volcano Scheduler
**Type:** Kubernetes Scheduler
**Repo:** volcano-sh/volcano

### Responsibilities:
1. ✅ Watch PodGroup resources
2. ✅ Implement gang scheduling algorithm
3. ✅ Wait until all pods in a gang can be scheduled
4. ✅ Atomically bind all pods together
5. ✅ Update PodGroup status (Inqueue → Running)
6. ✅ Generate scheduling events

### Does NOT do:
- ❌ Create PodGroups (LWS does this)
- ❌ Manage workload lifecycle

## How They Work Together

```
User creates LeaderWorkerSet
         ↓
LWS Controller creates:
  - 1 leader pod (schedulerName: volcano)
  - 3 worker pods (schedulerName: volcano)
  - 1 PodGroup (minMember: 4)
         ↓
Volcano Scheduler sees:
  - 4 pods referencing PodGroup
  - PodGroup requires minMember: 4
         ↓
Volcano waits until all 4 pods can be scheduled
         ↓
Volcano atomically schedules all 4 pods
         ↓
Volcano updates PodGroup status to Running
```

## What if you ONLY had LWS without Volcano?

**Answer:** You get individual pod scheduling (no gang scheduling)

The pods would be scheduled by default-scheduler one at a time, leading to partial deployments.

**Evidence:**
```bash
# With Volcano gang scheduling
kubectl get pods -n gang-demo -l leaderworkerset.sigs.k8s.io/name=gang-constrained
# Result: 0 running OR 4 running (all-or-nothing)

# Without gang scheduling
kubectl get pods -n gang-demo -l app=no-gang
# Result: 1 running, 3 pending (partial deployment)
```

## Other Gang Schedulers LWS Supports

LWS PR #498 (merged Aug 2025) added support for:
1. **Volcano** (implemented)
2. **Scheduler Plugins / Coscheduling** (mentioned in KEP, not yet in main PR)
3. **Future schedulers** (via SchedulerProvider interface)

The architecture allows LWS to integrate with ANY gang scheduler that uses PodGroups.

## Key Takeaway

**LWS has "gang scheduling support" = LWS can CREATE the objects gang schedulers need**

**LWS does NOT "do gang scheduling" = You still need an actual gang scheduler like Volcano**

This is similar to:
- Deployments create Pods, but kube-scheduler schedules them
- Jobs create Pods, but kube-scheduler schedules them
- LeaderWorkerSets create PodGroups, but Volcano schedules them

# Understanding Pod Lifecycle Event Generator (PLEG)

As discussed in the [PLEG design doc](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/node/pod-lifecycle-event-generator.md), kubelet reacts to two types of pod changes: pod spec changes in the control plane and changes to the container state. Prior to PLEG, kubelet had one goroutine per container that was periodically polling the container runtime, and PLEG was introduced to reduce unnecessary work and add parallelism to increase kubelet scalability.

### How PLEG works

PLEG is [initialized in kubelet.go](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/kubelet.go#L653), a health check is started and [PLEG is started](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/kubelet.go#L1418), which [calls relist in a loop](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/pleg/generic.go#L131). 

**Step 1: Get the pods**

Relist gets the pods from the [runtime manager](https://github.com/kubernetes/kubernetes/blob/7bf9b0a3beca74dabb85f1d0034ad78f689f807c/pkg/kubelet/kuberuntime/kuberuntime_manager.go#L315), which gets the status of the containers from the pod sandboxes. A pod sandbox is an abstraction over the container runtime that gets information about pods and containers without needing to understand the implementation details of the container runtime.

**Step 2: Update relist time**

[Relist time is updated](https://github.com/kubernetes/kubernetes/blob/7bf9b0a3beca74dabb85f1d0034ad78f689f807c/pkg/kubelet/pleg/generic.go#L209) after the pods are loaded. This is used for determine PLEG health and for generating timing metrics.

**Step 3: Pod cache is updated**

[The pod cache is updated, if there are pod events,](https://github.com/kubernetes/kubernetes/blob/7bf9b0a3beca74dabb85f1d0034ad78f689f807c/pkg/kubelet/pleg/generic.go#L250-L263) to reflect the current state of pods. This calls [GetPodStatus](https://github.com/kubernetes/kubernetes/blob/17312ea4a92a0bba31272a6709b37a88aa383b2d/pkg/kubelet/kuberuntime/kuberuntime_manager.go#L918-L980) to get the status of all containers (again), which it gets from the pod sandbox.

**Step 4: Update local storage**

[Pods are added to the local storage](https://github.com/kubernetes/kubernetes/blob/7bf9b0a3beca74dabb85f1d0034ad78f689f807c/pkg/kubelet/pleg/generic.go#L266), which is just stored in memory for the PLEG implementation to compare new and old states of the pods.

**Step 5: Attempt to send events**

[We attempt to put the events into the PLEG channel](https://github.com/kubernetes/kubernetes/blob/7bf9b0a3beca74dabb85f1d0034ad78f689f807c/pkg/kubelet/pleg/generic.go#L267-L278) that's managed outside of PLEG (more details below). If the channel is full, we just log and discard the events.

### What does it mean that PLEG is unhealthy?

When PLEG is considered unhealthy, the node is marked as `NotReady`. kubelet determines PLEG health by checking the timestamp for the last `relist`. Figuring out why PLEG is unhealthy is more complicated. [Kubelet registers a health check during initialization](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/kubelet.go#L655) that periodically checks the state of PLEG. The GenericPLEG provides [the Healthy() method](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/pleg/generic.go#L134-L148), which checks the last relist time. If the relist was more than the [relist threshold (currently 3 minutes)](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/pleg/generic.go#L83), PLEG is considered unhealthy. See code below:

```
// Healthy check if PLEG work properly.
// relistThreshold is the maximum interval between two relist.
func (g *GenericPLEG) Healthy() (bool, error) {
    relistTime := g.getRelistTime()
    if relistTime.IsZero() {
        return false, fmt.Errorf("pleg has yet to be successful")
    }
    // Expose as metric so you can alert on `time()-pleg_last_seen_seconds > nn`
    metrics.PLEGLastSeen.Set(float64(relistTime.Unix()))
    elapsed := g.clock.Since(relistTime)
    if elapsed > relistThreshold {
        return false, fmt.Errorf("pleg was last seen active %v ago; threshold is %v", elapsed, relistThreshold)
    }
    return true, nil
}
```

### What happens after PLEG puts events on the channel?

[After events are put into the event channel](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/pleg/generic.go#L273), the [syncLoopIteration in kubelet.go](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/kubelet.go#L1910-L1935) consumes that channel and takes action based on the event type, which may be updating timestamps, updating the record in the control plane and cleaning up pod sandboxes or containers.

**Can issues with the control plane cause PLEG to be unhealthy?**

No. The PLEG implementation has no dependencies on the control plane. Updates to the pod records in the control plane happen outside of PLEG, though issues with the control plane could result in updates not going through.

**Can a full event channel cause PLEG to go unhealthy?**

No. While [the channel does have a capacity of 1,000](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/kubelet.go#L148), [events are discarded if the channel is full](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/pleg/generic.go#L274-L276). To see if that's happening, you can view [this metric](https://github.com/kubernetes/kubernetes/blob/8466b5b4a7ff468498bdea9f81bd44ee8b692b7f/pkg/kubelet/metrics/metrics.go#L44) in Prometheus.

### What does cause PLEG to go unhealthy?

Since PLEG goes unhealthy if it takes too long to complete, it means that something is taking too long or is just stuck. Currently, there are no known issues with PLEG getting stuck due a bug in `relist`. Here are the mostly like causes:

1. A host has too many pods and it can't finish relist in less that 3 minutes.
2. The container runtime is slow or stuck.
3. The CNI is slow or stuck when getting pod network status.

## Useful metrics related to PLEG

Here is a list of some useful PLEG metrics. You can view them with Prometheus.

**NOTE:** [The metrics may be one of two names due to the renaming of some metrics.](https://github.com/kubernetes/kubernetes/commit/1a9b12176494cbba237142cfe4eee45309fc6369) The old names are noted below.

**PLEGRelistDuration - pleg_relist_duration_seconds**

[PLEGRelistDuration](https://github.com/kubernetes/kubernetes/blob/8466b5b4a7ff468498bdea9f81bd44ee8b692b7f/pkg/kubelet/metrics/metrics.go#L145-L155) indicates how long the relist took. If the PLEG is unhealthy or flapping between healthy and unhealthy, this would likely be longer than 3 minutes.

Deprecated Prometheus metric: `kubelet_pleg_relist_latency_microseconds`

Example Prometheus query:  `histogram_quantile(.99, sum(rate(kubelet_pleg_relist_duration_seconds_bucket[5m])) by (le))`

**PLEGRelistInterval - pleg_relist_interval_seconds**

[PLEGRelistInterval](https://github.com/kubernetes/kubernetes/blob/8466b5b4a7ff468498bdea9f81bd44ee8b692b7f/pkg/kubelet/metrics/metrics.go#L168-L176) indicates the time between relisting runs. This will be the relist interval (1s) plus the time it takes relist to update the cache and send events.

Deprecated Prometheus metric: `kubelet_pleg_relist_interval_microseconds`

**PLEGDiscardEvents - pleg_discard_events**

[PLEGDiscardEvents](https://github.com/kubernetes/kubernetes/blob/8466b5b4a7ff468498bdea9f81bd44ee8b692b7f/pkg/kubelet/metrics/metrics.go#L157-L164) indicate the number of events that were discarded because the event queue was full.

[This metric was added in v1.14 and has been unchanged.](https://github.com/kubernetes/kubernetes/commit/b52afc350ff93cf2b26831ef4b65e2610600d782)

## A little PLEG demonstration

Since PLEG is primarily impacted by the number of pods and containers you have running, the number of pod changes at a given time and the state of the node, we can demonstrate how that impacts how long PLEG takes to complete.

### Prerequisites

You need a kubernetes cluster with Prometheus installed. Follow instruction in the top-level README to set up Prometheus. Here's the command I used for this specific scenario:

```
eksctl create cluster --name $CLUSTERNAME --version $K8S_VERSION --region $REGION --nodegroup-name $NODEGROUP_NAME --nodes 3 --nodes-min 1 --nodes-max 3 --ssh-access --ssh-public-key $SSH_KEY
```

### Scenario 1: No Pods versus Many Pods

If you allow your cluster to run for a bit without any pods, you can see the baseline of running PLEG without any pods. Run `kubectl --namespace=prometheus port-forward deploy/kube-prometheus-server 9090` and go to `localhost:9090` in your browser. Paste in the below query to view 99th percentile metrics on some of the slowest PLEG runs:

Example Prometheus query:  `histogram_quantile(.99, sum(rate(kubelet_pleg_relist_duration_seconds_bucket[5m])) by (le))`

You should see the baseline time it takes to relist.

Now, create a bunch of pods: `kubectl apply -f pleg.yaml`. This just creates 66 pods, running 7 containers each, that just `echo` on a loop. If you reload the graph, you should see a large spike in PLEG relist time due to the number of pod changes and the baseline for relist should be slightly higher.

### Scenario 2: Increase load on nodes

If you increase the load on the node by putting CPU and I/O intensive workloads on the node, you can see the duration increase accordingly.

```
kubectl apply -f load.yaml
```

Once the pods are running, you'll be able to see that the relist time has increased disproportionately from the amount of additional pods.

## Open Issues Related to PLEG

### kubernetes/kubernetes

1. [Kubelet PLEG relist takes too long result in node notready](https://github.com/kubernetes/kubernetes/issues/95750)
2. [pleg unhealthy due to inspect one pod status from docker daemon timeout](https://github.com/kubernetes/kubernetes/issues/94829)
3. [The updatecache method of relist function in PLEG takes too long time to execute，resulting in PLEG health check timeout](https://github.com/kubernetes/kubernetes/issues/93886)
4. [Node flapping between Ready/NotReady with PLEG issues](https://github.com/kubernetes/kubernetes/issues/94525)
5. [Speed up getting pod statuses in PLEG when there are many changes](https://github.com/kubernetes/kubernetes/issues/26394)

### amazon-eks-ami

1. [Node NotReady because of PLEG is not healthy](https://github.com/awslabs/amazon-eks-ami/issues/195)
2. [Add more docker logging to Linux log collector](https://github.com/awslabs/amazon-eks-ami/issues/555)
3. [Nodes become unresponsive and doesnt recover with soft lockup error](https://github.com/awslabs/amazon-eks-ami/issues/454)

## Helpful Resources

* [This blog post provides a nice overview of how PLEG works with diagrams and code samples. I started here.](https://developers.redhat.com/blog/2019/11/13/pod-lifecycle-event-generator-understanding-the-pleg-is-not-healthy-issue-in-kubernetes/)
* [PLEG design proposal](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/node/pod-lifecycle-event-generator.md)

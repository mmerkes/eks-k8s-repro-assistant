# ALB ingress controller with ReadinessGate

This creates a service, ingress and deployment that utilize the ALB ingress controller and a ReadinessGate. You can scale the deployment and change configuration as needed for your scenario.

## Setup

**Install the ALB ingress controller.** See top-level README for more instructions. This scenario requires that to be installed before working.

The yaml is based on [the aws-alb-ingress-controller pod conditions docs.](https://kubernetes-sigs.github.io/aws-alb-ingress-controller/guide/ingress/pod-conditions/) See the docs for more information.

```
kubectl apply -f nginx.yaml
```

### Useful Prometheus Queries

View desired versus available versus unavailable replicas in a deployment:

```
kube_deployment_status_replicas_available{deployment="nginx-deployment"}
kube_deployment_status_replicas_unavailable{deployment="nginx-deployment"}
kube_deployment_status_replicas{deployment="nginx-deployment"}
```

You can put these into Grafana to see a nice diff.

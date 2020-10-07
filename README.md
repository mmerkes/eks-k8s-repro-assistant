# eks-k8s-repro-assistant

A set of utilities and instructions for reproducing and testing Kubernetes issues.

**NOTE:** The below scenarios and utilities may or may not have been successfully used to reproduce issues, so you should review the code and configuration accordingly and adjust if it's not meeting your needs.

## Setting up a cluster

### Set environment variables to be used across commands

```
export CLUSTERNAME=cluster-1-17
export K8S_VERSION=1.17
export REGION=us-east-2
export SSH_KEY=k8s_test
export NODEGROUP_NAME=test
export ACCOUNT_ID=111122223333
```

### Create an EKS cluster with eksctl

```
eksctl create cluster --name $CLUSTERNAME --version $K8S_VERSION --region $REGION --nodegroup-name $NODEGROUP_NAME \
    --nodes 1 --nodes-min 1 --nodes-max 1 --ssh-access --ssh-public-key $SSH_KEY
```

### Set up Prometheus monitoring

This is a shortening of [the EKS docs to set up Prometheus.](https://docs.aws.amazon.com/eks/latest/userguide/prometheus.html) Go to the docs if this gets out of date.

```
kubectl create namespace prometheus
helm install kube-prometheus stable/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="gp2",server.persistentVolume.storageClass="gp2"
# Verify that pods are ready
kubectl get pods -n prometheus
# Port forward console to local machine
kubectl --namespace=prometheus port-forward deploy/prometheus-server 9090
```

### Set up Grafana to view Prometheus metrics

[You need Grafana installed on your laptop for this to work,](https://grafana.com/grafana/download?platform=mac) but you can use Grafana to dashboard Prometheus metrics.

On a Mac:

```
brew update
brew install grafana
# Start grafana service
brew services start grafana
# Stop grafana service
brew services stop grafana
```

The below is a condensing of [these instructions.](https://prometheus.io/docs/visualization/grafana/)

1. Go to localhost:3000
2. Login with admin/admin
3. Change your password
4. Click "Add data source"
5. Select "Prometheus"
6. Set URL to http://localhost:9090. No other settings need to be set.
7. Click "Save and test"
8. Now, you can create dashboards in Grafana using Prometheus queries

### Set up metrics-server and Kubernetes dashboard

```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.7/components.yaml
# Wait for pods to be running
kubectl get deployments --all-namespaces | grep metrics-server
# Verify it's working
kubectl top node
# Install kubernetes dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.4/aio/deploy/recommended.yaml

kubectl apply -f setup/dashboard.yaml
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')

# Start a proxy to display dashboard
kubectl proxy
```

You can view the dashboard at http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/. You'll need to set up authentication. If it's just a dev cluster and you don't have significant security considerations, you can use an existing token set up for a service account:

```
# Get the names of your secrets
k get secrets
# Get the token and paste it in the console
k describe secret default-token-2jjt2 | grep token
```

### Set up ALB Ingress Controller

This is a shortening of [the EKS docs on how to set up the ALB ingress controller.](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)

```
eksctl utils associate-iam-oidc-provider \
    --region $REGION \
    --cluster $CLUSTERNAME \
    --approve

curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.8/docs/examples/iam-policy.json

aws iam create-policy \
    --policy-name ALBIngressControllerIAMPolicy \
    --policy-document file://iam-policy.json

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.8/docs/examples/rbac-role.yaml

eksctl create iamserviceaccount \
    --region $REGION \
    --name alb-ingress-controller \
    --namespace kube-system \
    --cluster $CLUSTERNAME \
    --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/ALBIngressControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --approve

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.8/docs/examples/alb-ingress-controller.yaml

# Edit the controller deployment
kubectl edit deployment.apps/alb-ingress-controller -n kube-system

# Add the arguments below with your values.
###########################################
    spec:
      containers:
      - args:
        - --ingress-class=alb
        - --cluster-name=<<CLUSTERNAME>>
        - --aws-vpc-id=<<VPC_ID, like vpc-03468a8157edca5bd>>
        - --aws-region=<<REGION>>
###########################################

# Confirm that the controller is running
kubectl get pods -n kube-system | grep alb-ingress-controller
```

## Setup Scenarios

### Scenario #1: Deployment using ALB ingress controller with ReadinessGate

This sets up a service, ingress and deployment with a readiness gate that utilizes the ALB ingress controller. See `scenarios/alb-ingress-with-readinessgate/README.md` for more details.

## Utilities

### Utility #1: Load balancer traffic generator

This sets up a deployment with pods that continually curl a configured endpoint to generate traffic. You can scale the deployment to increase the amount of traffic hitting your endpoint. See `utilities/lb-traffic-generator/README.md` for more details.

### Utility #2: Disk IO generator

This creates a deployment that constantly reads and writes from disk, intended to create IO pressure. See `utilities/disk-io-generator/README.md` for more details.

### Utility Scripts

The `utilities/scripts` directory is intended for scripts you run ad hoc on your development machine.

## Useful Prometheus Queries

**View nodes by ready status**

You can add the following to a Grafana dashboard to see the status of the different nodes and differentiate between ready, not ready and unknown.

```
sum(kube_node_status_condition{condition="Ready", status="true"})
sum(kube_node_status_condition{condition="Ready", status="false"})
sum(kube_node_status_condition{condition="Ready", status="unknown"})
```

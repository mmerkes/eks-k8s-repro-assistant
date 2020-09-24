# eks-k8s-repro-assistant

A set of utilities and instructions for reproducing and testing Kubernetes issues.

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
helm install prometheus stable/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="gp2",server.persistentVolume.storageClass="gp2"
# Verify that pods are ready
kubectl get pods -n prometheus
# Port forward console to local machine
kubectl --namespace=prometheus port-forward deploy/prometheus-server 9090
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

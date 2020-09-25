# Load balancer traffic generator

This creates a deployment that constantly curls a specific endpoint. You can increase the load by increasing the number of replicas in the deployment.

## Setup

To set up `hammertime`, you need to update the yaml with your configuration, build and push a Docker image and apply the configuration to your cluster.

**Step 1**: Set some environment variables before running commands.

```
export REGION=us-east-2
export ACCOUNT_ID=111122223333
```

**Step 2**: Prepare container for deployment.

```
aws ecr create-repository --repository-name hammertime --region $REGION
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker build -t hammertime .
docker tag hammertime:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/hammertime:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/hammertime:latest
```

**Step 3**: Edit `hammertime.yaml` to include your configuration

Replace `<REGION>`, `<ACCOUNT_ID>` and `<ENDPOINT_TO_HAMMER>` with the correct values.

**Step 4**: Deploy and verify pod is working

```
kubectl apply -f hammertime.yaml

# Verify pod is running
kubectl get pods | grep hammertime
```

For additional validation, verify in the EC2, CloudWatch or Prometheus console that the load balancer is receiving requests.

## Usage

Edit the number of replicas in `hammertime.yaml` to increase or decrease the load on the endpoint.

```
kubectl apply -f hammertime.yaml
```

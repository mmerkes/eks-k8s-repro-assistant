# Disk IO Generator

This creates a deployment that constantly reads and writes from disk, intended to create IO pressure.

## Setup

To set up `disk-io-generator`, you need to update the yaml with your configuration, build and push a Docker image and apply the configuration to your cluster.

**Step 1**: Set some environment variables before running commands.

```
export REGION=us-east-2
export ACCOUNT_ID=111122223333
```

**Step 2**: Prepare container for deployment.

```
aws ecr create-repository --repository-name disk-io-generator --region $REGION
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker build -t disk-io-generator .
docker tag disk-io-generator:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/disk-io-generator:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/disk-io-generator:latest
```

**Step 3**: Edit `disk-io-generator.yaml` to include your configuration

Replace `<REGION>` and `<ACCOUNT_ID>`with the correct values.

**Step 4**: Deploy and verify pod is working

```
kubectl apply -f disk-io-generator.yaml

# Verify pod is running
kubectl get pods | grep disk-io-generator
```

For additional validation, verify in the EC2, CloudWatch or Prometheus console that the load balancer is receiving requests.

## Usage

Edit the number of replicas in `disk-io-generator.yaml` to increase or decrease the load on disk.

```
kubectl apply -f disk-io-generator.yaml
```

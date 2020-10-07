# Git Cloner

Clones and then repeatedly zips and unzips the contents.

## Setup

To set up `git-cloner`, you need to update the yaml with your configuration, build and push a Docker image and apply the configuration to your cluster.

**Step 1**: Set some environment variables before running commands.

```
export REGION=us-east-2
export ACCOUNT_ID=111122223333
```

**Step 2**: Prepare container for deployment.

```
aws ecr create-repository --repository-name git-cloner --region $REGION
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker build -t git-cloner .
docker tag git-cloner:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/git-cloner:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/git-cloner:latest
```

**Step 3**: Edit `git-cloner.yaml` to include your configuration

Replace `<REGION>` and `<ACCOUNT_ID>`with the correct values.

**Step 4**: Deploy and verify pod is working

```
kubectl apply -f git-cloner.yaml

# Verify pod is running
kubectl get pods | grep git-cloner
```

For additional validation, you can log into a pod and verify that logs are going into `git-cloner.yaml`.

## Usage

Edit the number of replicas in `git-cloner.yaml` to increase or decrease the load.

```
kubectl apply -f git-cloner.yaml
```

# Decompression Loop

This scenario continually decompresses the AWS Go SDK to generate I/O on a node. This scenario was created to reproduce [this issue](https://github.com/awslabs/amazon-eks-ami/issues/454), which was causing soft lockups on EC2 instances using the 4.14 Linux kernel.

## Running Scenario

Create a cluster if you don't already have one with nodes:

```
# Set a few environment variables
export CLUSTERNAME=decompression-loop
export K8S_VERSION=1.17
export REGION=us-east-2
# Choose your own key
export SSH_KEY=k8s_node
export NODEGROUP_NAME=ng
# Update the account ID
export ACCOUNT_ID=111111111111

eksctl create cluster --name $CLUSTERNAME --version $K8S_VERSION --region $REGION --nodegroup-name $NODEGROUP_NAME --nodes 1 --nodes-min 1 --nodes-max 1 --ssh-access --ssh-public-key $SSH_KEY --node-type m5.2xlarge
```

To run the pod, you'll need to load the compressed AWS Go SDK to an S3 bucket. In tests, uploading the tarball to S3 yielded more consistent results, perhaps because I was compressing on a Mac and decompressing on Linux.

```
export REGION=us-east-2

# Download and compress the AWS Go SDK
git clone https://github.com/aws/aws-sdk-go.git && tar cvf sdk.tar.gz aws-sdk-go
# Upload the 
aws s3api create-bucket --bucket decompression-loop --region $REGION --create-bucket-configuration LocationConstraint=$REGION
aws s3 cp sdk.tar.gz s3://decompression-loop/sdk.tar.gz
```

Create the Kubernetes deployment:

```
kubectl apply -f decompression-loop
```

If you are running AmazonLinux with kernel `4.14.198` or older, you should see the soft lockup issue reproduced within a couple of minutes. You will be unable to SSH onto the instance and the node will eventually be marked as `NotReady`.

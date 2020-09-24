# Scripts

Collection of various utility scripts.

## Instructions

### Constant scaler

This script continually scales a deployment up and down. This is useful for scenarios that require scaling. You can edit `constant-scaler.sh` accordingly to get the desired scale, timeouts, etc.

```
export DEPLOYMENT_NAME=nginx-deployment
./constant-scaler.sh
```

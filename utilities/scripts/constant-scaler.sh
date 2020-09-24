#!/bin/bash

for i in {1..5000}
do
   echo "Running $i times"
   date
   echo "Scaling up"
   kubectl scale deployment $DEPLOYMENT_NAME --replicas=6
   # Wait until deployment is fully scaled
   until kubectl get deployments | grep $DEPLOYMENT_NAME | grep "6/6" > /dev/null;
   do
     sleep 1
     echo -n .
   done
   echo "Done scaling up"
   sleep 15
   date
   echo "Scaling down"
   kubectl scale deployment $DEPLOYMENT_NAME --replicas=3
   sleep 20
done

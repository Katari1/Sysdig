#!/bin/bash
echo "Deleting namespace sysdigcloud"
kubectl delete ns sysdigcloud

echo "Deleting namespace sysdig-agents"
kubectl delete ns sysdig-agents

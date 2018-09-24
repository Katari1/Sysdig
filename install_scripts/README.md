These are my install scripts for deploying backend Sysdig.  This will deploy a full working backend and agents.  Please note that k8 one is fully working but the openshift one I haven't messed with in a while.

Assumptions:
1.  You have jq installed.
2.  You cloned the repo https://github.com/draios/sysdigcloud-kubernetes and put the install script in the base directory sysdigcloud-kubernetes
3.  You have the correct files cloned from the https://github.com/draios/sysdig-cloud-scripts/tree/master/agent_deploy/kubernetes.  NOTE I renamd the sysdig-agent-daemonset-v2.yaml to agent_deployment.yaml and teh sysdig-agent-configmap.yaml to agent_config.yaml and that they are in a folder called agents in the root directory.

#!/bin/bash
#colors
WHITE='\033[1;37m'
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e  "${GREEN}*******************Creating samespace sysdigcloud*******************${NC}"
kubectl create namespace sysdigcloud

echo -e "${GREEN}*******************Creating configmap from sysdigcloud/config.yaml*******************${NC}"
kubectl -n sysdigcloud create -f sysdigcloud/config.yaml

echo -e "${GREEN}*******************Creating quay secret*******************${NC}"
kubectl -n sysdigcloud create -f sysdigcloud/pull-secret.yaml

#echo "Creating SSL certificates"
#openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=onprem.sysdigcloud.com" -keyout server.key -out server.crt

echo -e "${GREEN}*******************Creating k8 ssl secret*******************${NC}"
kubectl -n sysdigcloud create secret tls sysdigcloud-ssl-secret --cert=server.crt --key=server.key

#echo "Creating storageclass"
#kubectl apply -f storageclasses/sdc-storageclass.yaml

echo -e "${GREEN}*******************Creating cassandra pods*******************${NC}"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/cassandra/cassandra-service.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/cassandra/cassandra-statefulset.yaml

echo -e "${GREEN}*******************Creating elastic search pods*******************${NC}"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/elasticsearch/elasticsearch-service.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/elasticsearch/elasticsearch-statefulset.yaml

echo -e "${GREEN}*******************Creating Mysql Instances*******************${NC}"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/mysql/mysql-cluster-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/mysql/mysql-router-statefulset.yaml

echo -e "${GREEN}*******************Creating Redis Instances*******************${NC}"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-primary-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-primary-svc-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-secondary-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-secondary-svc-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-sentinel-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-sentinel-svc-statefulset.yaml


echo -e "${RED}*******************Sleeping for two minutes*******************${NC}"
sleep 120s

echo -e "${GREEN}*******************Deploying backend*******************${NC}"
kubectl -n sysdigcloud create -f sysdigcloud/sdc-api.yaml
echo -e "${RED}*******************Sleeping for one minute*******************${NC}"
sleep 60s
kubectl -n sysdigcloud create -f sysdigcloud/sdc-collector.yaml
kubectl -n sysdigcloud create -f sysdigcloud/sdc-worker.yaml

echo -e "${GREEN}*******************Creating loadbalancer for API and Collector*******************${NC}"
kubectl -n sysdigcloud create -f sysdigcloud/api-loadbalancer-service.yaml
kubectl -n sysdigcloud create -f sysdigcloud/collector-loadbalancer-service.yaml

echo -e "${RED}*******************Letting everything catch up (DNS for LB)*******************${NC}"
sleep 240s


echo -e "${GREEN}}*******************Deploying Agents*******************${NC}"
api_url=$(kubectl get services -o wide -n sysdigcloud | grep api | awk {'print $4'})
collector_url=$(kubectl get services -o wide -n sysdigcloud | grep collector | awk {'print $4'})
cce=$(grep collector: agents/agent_config_ha.yaml)

echo -e  "${PURPLE}******************* Your URL is https://$api_url******************************${NC}"

accessKey=$(curl -s -k "https://$api_url:443/api/login" -H 'X-Sysdig-Product: SDC' -H 'Content-Type: application/json' --compressed --data-binary '{"username":"test@sysdig.com","password":"test"}' | jq . | grep accessKey | awk 'NR==1 {print $2}')

accessKey=$(echo $accessKey | sed -e 's/^"//' -e 's/"$//' <<<"$accessKey")

echo -e "${PURPLE}*******************Your Access Key is: $accessKey*******************${NC}"

echo -e "${PURPLE}*******************Your collector URL is: $collector_url*******************${NC}"

echo -e "${GREEN}*******************Fixing collector in yaml*******************${NC}"
sed -i -e "s/$cce/     collector: $collector_url/g" agents/agent_config_ha.yaml


echo -e "${GREEN}*******************Creating namespace sysdig-agents*******************${NC}"
kubectl create namespace sysdig-agents

echo -e "${GREEN}*******************creating secret for accessKey*******************${NC}"
kubectl create secret generic sysdig-agent --from-literal=access-key=$accessKey -n sysdig-agents

echo -e "${GREEN}*******************creating clusterrole*******************${NC}"
kubectl apply -f agents/agent_clusterrole.yaml -n sysdig-agents

echo -e "${GREEN}*******************creating service account*******************${NC}"
kubectl create serviceaccount sysdig-agent -n sysdig-agents

echo -e "${GREEN}*******************Creating clusterrole binding*******************${NC}"
kubectl create clusterrolebinding sysdig-agent --clusterrole=sysdig-agent --serviceaccount=sysdig-agents:sysdig-agent

echo -e "${GREEN}*******************Deploying Agent Config*******************${NC}"
kubectl apply -f agents/agent_config_ha.yaml -n sysdig-agents

echo -e "${GREEN}*******************Deploying Agents*******************${NC}"
kubectl apply -f agents/agent_deployment.yaml -n sysdig-agents

echo -e "${WHITE}*******************It will take about two minutes for the agents to come up.  HAPPY HACKING*******************"

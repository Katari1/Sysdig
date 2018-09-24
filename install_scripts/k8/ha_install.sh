#!/bin/bash


echo "*******************Creating samespace sysdigcloud*******************"
kubectl create namespace sysdigcloud

echo "*******************Creating configmap from sysdigcloud/config.yaml*******************"
kubectl -n sysdigcloud create -f sysdigcloud/config.yaml

echo "*******************Creating quay secret*******************"
kubectl -n sysdigcloud create -f sysdigcloud/pull-secret.yaml

#echo "Creating SSL certificates"
#openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=onprem.sysdigcloud.com" -keyout server.key -out server.crt

echo "*******************Creating k8 ssl secret*******************"
kubectl -n sysdigcloud create secret tls sysdigcloud-ssl-secret --cert=server.crt --key=server.key

#echo "Creating storageclass"
#kubectl apply -f storageclasses/sdc-storageclass.yaml

echo "*******************Creating cassandra pods*******************"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/cassandra/cassandra-service.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/cassandra/cassandra-statefulset.yaml

echo "*******************Creating elastic search pods*******************"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/elasticsearch/elasticsearch-service.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/elasticsearch/elasticsearch-statefulset.yaml

echo "*******************Creating Mysql Instances*******************"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/mysql/mysql-cluster-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/mysql/mysql-router-statefulset.yaml

echo "*******************Creating Redis Instances*******************"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-primary-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-primary-svc-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-secondary-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-secondary-svc-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-sentinel-statefulset.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-sentinel-svc-statefulset.yaml


echo "*******************Sleeping for two minutes*******************"
sleep 120s

echo "*******************Deploying backend*******************"
kubectl -n sysdigcloud create -f sysdigcloud/sdc-api.yaml
echo "*******************Sleeping for one minute*******************"
sleep 60s
kubectl -n sysdigcloud create -f sysdigcloud/sdc-collector.yaml
kubectl -n sysdigcloud create -f sysdigcloud/sdc-worker.yaml

echo "*******************Creating loadbalancer for API and Collector*******************"
kubectl -n sysdigcloud create -f sysdigcloud/api-loadbalancer-service.yaml
kubectl -n sysdigcloud create -f sysdigcloud/collector-loadbalancer-service.yaml

echo "*******************Letting everything catch up (DNS for LB)*******************"
sleep 120s


echo "*******************Deploying Agents*******************"
api_url=$(kubectl get services -o wide -n sysdigcloud | grep api | awk {'print $4'})
collector_url=$(kubectl get services -o wide -n sysdigcloud | grep collector | awk {'print $4'})
cce=$(grep collector: agents/agent_config_ha.yaml)

echo "******************* Your URL is https://$api_url******************************"

accessKey=$(curl -s -k "https://$api_url:443/api/login" -H 'X-Sysdig-Product: SDC' -H 'Content-Type: application/json' --compressed --data-binary '{"username":"test@sysdig.com","password":"test"}' | jq . | grep accessKey | awk 'NR==1 {print $2}')

accessKey=$(echo $accessKey | sed -e 's/^"//' -e 's/"$//' <<<"$accessKey")

echo "*******************Your Access Key is: $accessKey*******************"

echo "*******************Your collector URL is: $collector_url*******************"

echo "*******************Fixing collector in yaml*******************"
sed -i -e "s/$cce/     collector: $collector_url/g" agents/agent_config_ha.yaml


echo "*******************Creating namespace sysdig-agents*******************"
kubectl create namespace sysdig-agents

echo "*******************creating secret for accessKey*******************"
kubectl create secret generic sysdig-agent --from-literal=access-key=$accessKey -n sysdig-agents

echo "*******************creating clusterrole*******************"
kubectl apply -f agents/agent_clusterrole.yaml -n sysdig-agents

echo "*******************creating service account*******************"
kubectl create serviceaccount sysdig-agent -n sysdig-agents

echo "*******************Creating clusterrole binding*******************"
kubectl create clusterrolebinding sysdig-agent --clusterrole=sysdig-agent --serviceaccount=sysdig-agents:sysdig-agent

echo "*******************Deploying Agent Config*******************"
kubectl apply -f agents/agent_config_ha.yaml -n sysdig-agents

echo "*******************Deploying Agents*******************"
kubectl apply -f agents/agent_deployment.yaml -n sysdig-agents


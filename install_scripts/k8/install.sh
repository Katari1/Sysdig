#!/bin/bash


echo "Creating samespace sysdigcloud"
kubectl create namespace sysdigcloud

echo "Creating configmap from sysdigcloud/config.yaml"
kubectl -n sysdigcloud create -f sysdigcloud/config.yaml

echo "Creating quay secret"
kubectl -n sysdigcloud create -f sysdigcloud/pull-secret.yaml

echo "Creating SSL certificates"
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=onprem.sysdigcloud.com" -keyout server.key -out server.crt

echo "Creating k8 ssl secret"
kubectl -n sysdigcloud create secret tls sysdigcloud-ssl-secret --cert=server.crt --key=server.key

echo "Creating storageclass"
kubectl apply -f storageclasses/sdc-storageclass.yaml

echo "Creating cassandra pods"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/cassandra/cassandra-service.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/cassandra/cassandra-statefulset.yaml

echo "Creating elastic search pods"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/elasticsearch/elasticsearch-service.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/elasticsearch/elasticsearch-statefulset.yaml

echo "Creating Mysql Instances"
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/mysql.yaml
kubectl -n sysdigcloud create -f datastores/as_kubernetes_pods/manifests/redis/redis-deployment.yaml

echo "Sleeping for two minutes"
sleep 120s

echo "Deploying backend"
kubectl -n sysdigcloud create -f sysdigcloud/sdc-api.yaml
kubectl -n sysdigcloud create -f sysdigcloud/sdc-collector.yaml
kubectl -n sysdigcloud create -f sysdigcloud/sdc-worker.yaml

echo "Creating loadbalancer for API and Collector"
kubectl -n sysdigcloud create -f sysdigcloud/api-loadbalancer-service.yaml
kubectl -n sysdigcloud create -f sysdigcloud/collector-loadbalancer-service.yaml

echo "Showing container status"
kubectl get pods -n sysdigcloud

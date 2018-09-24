#!/bin/bash

echo "Creating project"
oc new-project sysdigcloud

echo "Allowing container to run as root"
oc adm policy add-scc-to-user privileged -n sysdigcloud -z default


echo "Creating configmap"
oc create -f sysdigcloud/config.yaml

echo "Creating quay pull secret"
oc create -f sysdigcloud/pull-secret.yaml

echo "Creating ssl secret"
oc create secret tls sysdigcloud-ssl-secret --cert=server.crt --key=server.key

echo "Creating storage class"
oc create -f storageclasses/sdc-storageclass.yaml

echo "Creating cassandra"
oc create -f datastores/as_kubernetes_pods/manifests/cassandra/cassandra-service.yaml
oc create -f datastores/as_kubernetes_pods/manifests/cassandra/cassandra-statefulset.yaml

echo "Creating elasticsearch"
oc create -f datastores/as_kubernetes_pods/manifests/elasticsearch/elasticsearch-service.yaml
oc create -f datastores/as_kubernetes_pods/manifests/elasticsearch/elasticsearch-statefulset.yaml

echo "Creating Mysql containers"
oc create -f datastores/as_kubernetes_pods/manifests/mysql.yaml
oc create -f datastores/as_kubernetes_pods/manifests/redis/redis-deployment.yaml

echo "Deploying Backend"
oc create -f sysdigcloud/sdc-api.yaml
oc create -f sysdigcloud/sdc-collector.yaml
oc create -f sysdigcloud/sdc-worker.yaml

echo "Creating load balancers"
oc create -f sysdigcloud/api-loadbalancer-service.yaml
oc create -f sysdigcloud/collector-loadbalancer-service.yaml

echo "Displaying containers"
oc get pods

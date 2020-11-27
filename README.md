# Orchid

Repository for the Orchid project

![OrchidArch](orchid-architecture.png)

## Web UI

The Thingsboard Web UI is accessible from https://tb-web-ui.orchid.test.strapkube.com/login
The administration account is *sysadmin@thingsboard.org*.

## MQTT

Here is the MQTT contact point
* **IP** : 52.169.159.181
* **PORT** : 1883

## Requirements

* Install the [Azure cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* Install [kubectx](https://github.com/ahmetb/kubectx)
* Install HELM 2
* Install kubectl

## Kubernetes context

1. Import the [AKS credentials](https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az_aks_get_credentials)
2. Switch to the orchid1 context:
```
kubectx orchid1
```

## Thingsboard Install

Use https://github.com/strapdata/k8s-thingsboard

### Dockerhub secret

Thingsboard requires a [dockerhub](https://hub.docker.com/) account to download docker images from dockerhub, see [thingsboard doc](https://thingsboard.io/docs/user-guide/install/pe/cluster/minikube-cluster-setup/#step-1-checkout-all-thingsboard-pe-images). The username and password of this dockerhub account must be stored in a Kubernetes secret with type **kubernetes.io/.dockerconfigjson** named **dockerhub** used as an imagePullSecret. Creating such secret is documented [here](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)

Create a dockerhub secret for the temporary orchidtmp2 dockerhub account:
```
kubectl create secret docker-registry dockerhub --docker-server=https://index.docker.io/v1/ --docker-username=orchidtmp2 --docker-password=***** --docker-email=orchid@elassandra.io
```

## Usage

Dashboard Traefik:
https://traefik.orchid.test.strapkube.com/dashboard/

Console Thingsboard
https://tb-web-ui.orchid.test.strapkube.com/

### Thingsboard license reset

Thingsboard nodes are registered on startup to get a license record stored in **/data** by default. Unfortunately, Thingsboard provides a deployment manifest to deploy the tb-node,
and the license record is sometime lost. As the result, the tb-node failed to restart with the following error in logs:

```
2020-11-20 22:10:26,160 [main] INFO  o.t.license.client.TbLicenseClient - Initializing ThingsBoard License Client, Release Date [2020-01-08]
2020-11-20 22:10:27,320 [main] ERROR o.t.license.client.TbLicenseClient - License Error: ACTIVE_INSTANCES_CAPACITY_EXCEEDED(104) - Active instances capacity exceeded!
2020-11-20 22:10:27,320 [main] ERROR o.t.license.client.TbLicenseClient - Failed to initialize ThingsBoard License Client!
2020-11-20 22:10:27,326 [main] ERROR o.t.s.d.s.BasicSubscriptionService - Failed to init license client
org.thingsboard.license.shared.exception.LicenseException: Active instances capacity exceeded!
	at org.thingsboard.license.shared.exception.LicenseErrorResponse.toLicenseException(LicenseErrorResponse.java:69)
	at org.thingsboard.license.client.TbLicenseClient.toLicenseException(TbLicenseClient.java:378)
	at org.thingsboard.license.client.TbLicenseClient.activateInstance(TbLicenseClient.java:316)
	at org.thingsboard.license.client.TbLicenseClient.readInstanceDataOrActivate(TbLicenseClient.java:301)
	at org.thingsboard.license.client.TbLicenseClient.init(TbLicenseClient.java:156)
	at org.thingsboard.server.dao.subscription.BasicSubscriptionService.init(BasicSubscriptionService.java:102)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
```

In such case, you need to:
1. Disable the tb-node pod:
```
kubectl scale --replicas=0 deployment.apps/tb-node
```

2. Reset the registered license in the Thingsboard website.

3. Enable the tb-node pod:
```
kubectl scale —-replicas=1 deployment.apps/tb-node
```

According to thingsboard support (2020/08/05), the tb-node should deployed as a Kubernetes statefulset to store the license record in /data on a persistent PVC.
(The default location /date can be changed with the env variable TB_LICENSE_INSTANCE_DATA_FILE)

## Backup Thingsboard data

Open an interactive bash session in the Elassandra/Cassandra pod:
```
kubectl exec -it elassandra-orchid-dc1-0-0 -- bash
```

Load useful aliases in your session:
```
source /usr/share/cassandra/aliases.sh
```

Snapshot the thingsboard keyspace:
```
nodetool snapshot thingsboard --tag snap-20201127
```

Build a tarball including snapshot files.
```
find /var/lib/cassandra -name snap-20201127 -print0 | xargs -0 tar cfz /var/lib/cassandra/snap-20201127.tgz
```

Backup the thingsboard keyspace schema:
```
cqlsh -e "desc keyspace thingsboard" > /tmp/thingsboard-20201127.cql
```

Exit the Cassandra container:
```
exit
```

Copy the schema and snapshot from the container to your desktop:
```
kubectl cp default/elassandra-orchid-dc1-0-0:/tmp/thingsboard-20201127.cql thingsboard-20201127.cql
kubectl cp default/elassandra-orchid-dc1-0-0:/var/lib/cassandra/snap-20201127.tgz snap-20201127.tgz
```

## Backup kubernetes manifest

Backup the Cassandra statefulset manifest:
```
kubectl get statefulset.apps/elassandra-orchid-dc1-0 -o yaml > elassandra-orchid-dc1-0-sts-20201127.yaml
```

## Update Treafik config

Check HELM releases:
```
helm list -a
NAME      	REVISION	UPDATED                 	STATUS  	CHART                          	APP VERSION	NAMESPACE
orchid-dc1	1       	Thu Jan 16 11:17:50 2020	DEPLOYED	elassandra-datacenter-0.3.0-rc1	1.0        	default
traefik   	5       	Fri Nov 27 11:26:15 2020	DEPLOYED	traefik-1.86.1                 	1.7.20     	kube-system
```

Get the current traefik configuration
```
helm get traefik
```

Disable enforced ssl:
```
helm upgrade traefik ./traefik --reuse-values --set ssl.enforced=false
```

Note: Traefik can generate a TLS certificate+key through ACME, but this requires credentials to update a DNS zone, see [Traefik documentation](https://doc.traefik.io/traefik/v1.7/configuration/acme/)

Update the DNS domain:
```
sed 's/orchid.azure.strapcloud.com/app.orchid-solution.fr/g' k8s-thingsboard/thingsboard-ingress-traefik.yml > k8s-thingsboard/thingsboard-ingress-traefik2.yml
kubectl apply -n default -f k8s-thingsboard/thingsboard-ingress-traefik2.yml
helm upgrade traefik ./traefik --reuse-values --set dashboard.domain=traefik.app.orchid-solution.fr
```

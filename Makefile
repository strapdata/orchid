.PHONY: init 
KB := kubectl

init:
	rm $(KUBECONFIG) || echo "deleted"
	az aks get-credentials --name $(K8S_CLUSTER_NAME) --resource-group $(RESOURCE_GROUP_NAME) --output table -f $(KUBECONFIG)
	$(KB) config use-context $(K8S_CLUSTER_NAME)
	$(KB) config set-context $(K8S_CLUSTER_NAME) --cluster=$(K8S_CLUSTER_NAME)


# SHELL := /bin/bash

RELEASE := cert-manager
NAMESPACE := cert-manager

CHART_NAME := jetstack/cert-manager
CHART_VERSION ?= 0.14.3
#If changing chart version here, also update create_crds.sh
#Unless your upgrading to 0.15.x where you can create creds
#via helm.

DEV_CLUSTER ?= testrc
DEV_PROJECT ?= jendevops1
DEV_ZONE ?= australia-southeast1-c


.DEFAULT_TARGET: status

lint:
	@find . -type f -name '*.yml' | xargs yamllint
	@find . -type f -name '*.yaml' | xargs yamllint

init:
	helm3 repo add jetstack https://charts.jetstack.io
	helm3 repo update

dev: lint init
	gcloud config set project $(DEV_PROJECT)
	gcloud container clusters get-credentials $(DEV_CLUSTER) --zone $(DEV_ZONE) --project $(DEV_PROJECT)

#Install the CustomResourceDefinition resources first separately
	./create_crds.sh

	-kubectl label namespace $(NAMESPACE) certmanager.k8s.io/disable-validation=true
	helm3 upgrade --install --force --wait $(RELEASE) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		-f values.yaml \
		$(CHART_NAME)
	$(MAKE) history

#Create ClusterIssuers
	./create_clusterissuer.sh

prod: lint init
ifndef CI
	$(error Please commit and push, this is intended to be run in a CI environment)
endif
	gcloud config set project $(PROD_PROJECT)
	gcloud container clusters get-credentials $(PROD_PROJECT) --zone $(PROD_ZONE) --project $(PROD_PROJECT)

#Install the CustomResourceDefinition resources first separately
		./create_crds.sh

	-kubectl label namespace $(NAMESPACE) certmanager.k8s.io/disable-validation=true
	helm3 upgrade $(RELEASE) $(CHART_NAME) \
		--install --force --wait
		--create-namespace=$(NAMESPACE) \
		-f values.yaml
	$(MAKE) history

#Create ClusterIssuers
#	./create_clusterissuer.sh

destroy:
	helm delete --purge $(RELEASE)

history:
	helm history $(RELEASE) --max=5

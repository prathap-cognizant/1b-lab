#!/bin/bash
set -e

RG=1bv2-dapr-rg
LOC=eastus
ACR=1bv2dapracr$RANDOM
ENV=1bv2-dapr-env
SB=acadapr-sb-$RANDOM
PS_APP=productservice
OS_APP=orderservice

az group create -n $RG -l $LOC
az acr create -n $ACR -g $RG --sku Basic
az acr login -n $ACR

# requires local Docker
# docker build -t $ACR.azurecr.io/productservice:1.0.0 ./ProductService
# docker push $ACR.azurecr.io/productservice:1.0.0
# docker build -t $ACR.azurecr.io/orderservice:1.0.0 ./OrderService
# docker push $ACR.azurecr.io/orderservice:1.0.0

# cloud build in ACR - no local Docker needed
az acr build -r $ACR -t productservice:1.0.0 ./ProductService
az acr build -r $ACR -t orderservice:1.0.0   ./OrderService

LAW_ID=$(az monitor log-analytics workspace create -g $RG -n 1bv2-dapr-env-logs --query id -o tsv)
LAW_WS=$(az monitor log-analytics workspace show -g $RG -n 1bv2-dapr-env-logs --query customerId -o tsv)
LAW_KEY=$(az monitor log-analytics workspace get-shared-keys -g $RG -n 1bv2-dapr-env-logs --query primarySharedKey -o tsv)

az containerapp env create -g $RG -n $ENV -l $LOC --logs-workspace-id $LAW_WS --logs-workspace-key $LAW_KEY

az servicebus namespace create -g $RG -n $SB -l $LOC --sku Standard
az servicebus topic create -g $RG --namespace-name $SB --name products
SB_CONN=$(az servicebus namespace authorization-rule keys list -g $RG --namespace-name $SB --name RootManageSharedAccessKey --query primaryConnectionString -o tsv)

az containerapp env dapr-component set --name $ENV --resource-group $RG --dapr-component-name sb-pubsub --yaml ./aca/pubsub-servicebus.yaml --secrets servicebus-connection="$SB_CONN"

az containerapp create -g $RG -n $PS_APP --environment $ENV --image $ACR.azurecr.io/productservice:1.0.0 --ingress external --target-port 8080 --registry-server $ACR.azurecr.io --enable-dapr --dapr-app-id $PS_APP --dapr-app-port 8080 --env-vars PubSubName=sb-pubsub

az containerapp create -g $RG -n $OS_APP --environment $ENV --image $ACR.azurecr.io/orderservice:1.0.0 --ingress internal --target-port 8080 --registry-server $ACR.azurecr.io --enable-dapr --dapr-app-id $OS_APP --dapr-app-port 8080 --env-vars PubSubName=sb-pubsub

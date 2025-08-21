#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(dirname "$(realpath "$0")")

# ==== CONFIG ====
RG=${RG:-1bv4-dapr-rg}
LOC=${LOC:-eastus}
ACR=${ACR:-acadapracr$RANDOM}
ENV=${ENV:-1bv4-dapr-env}
SB=${SB:-dapr-sb-$RANDOM}
PS_APP=${PS_APP:-productservice}
OS_APP=${OS_APP:-orderservice}

echo "Step #1 Create resource group"
az group create -n "$RG" -l "$LOC" -o table

echo "Step #2 Create ACR"
az acr create -n "$ACR" -g "$RG" --sku Basic -o table

echo "Step #3 Cloud builds in ACR (no local Docker required)"
az acr build -r $ACR -t productservice:1.0.0 ./ProductService
az acr build -r $ACR -t orderservice:1.0.0   ./OrderService

echo "Step #4 Create Log Analytics workspace and ACA environment"
LAW_WS=$(az monitor log-analytics workspace create -g "$RG" -n ${ENV}-logs --query customerId -o tsv | tr -d '[:space:]')
LAW_KEY=$(az monitor log-analytics workspace get-shared-keys -g "$RG" -n ${ENV}-logs --query primarySharedKey -o tsv)

az extension add --name containerapp --upgrade --allow-preview true
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights

az containerapp env create -g "$RG" -n "$ENV" -l "$LOC" --logs-workspace-id "$LAW_WS" --logs-workspace-key "$LAW_KEY" -o table

echo "Step #5 Create Azure Service Bus (Standard) with topic"
az servicebus namespace create -g "$RG" -n "$SB" -l "$LOC" --sku Standard -o table
az servicebus topic create -g "$RG" --namespace-name "$SB" --name products -o table

echo "Step #6 Get Service Bus connection string"
SB_CONN=$(az servicebus namespace authorization-rule keys list -g "$RG" --namespace-name "$SB" --name RootManageSharedAccessKey --query primaryConnectionString -o tsv)

echo "Step #7 Add Dapr component to ACA environment (Service Bus topics)"
az containerapp env dapr-component set --name "$ENV" --resource-group "$RG" --dapr-component-name sb-pubsub --yaml "$ROOT_DIR/aca/pubsub-servicebus.yaml" --secrets servicebus-connection="$SB_CONN"

echo "Step #8 Deploy ProductService (publisher)"
az containerapp create -g "$RG" -n "$PS_APP" --environment "$ENV" --image $ACR.azurecr.io/productservice:1.0.0 --ingress external --target-port 8080 --registry-server $ACR.azurecr.io --enable-dapr --dapr-app-id "$PS_APP" --dapr-app-port 8080 --env-vars PubSubName=sb-pubsub -o table

echo "Step #9 Deploy OrderService (subscriber)"
az containerapp create -g "$RG" -n "$OS_APP" --environment "$ENV" --image $ACR.azurecr.io/orderservice:1.0.0 --ingress internal --target-port 8080 --registry-server $ACR.azurecr.io --enable-dapr --dapr-app-id "$OS_APP" --dapr-app-port 8080 --env-vars PubSubName=sb-pubsub -o table

echo "[✓] Completed. Use the following to stream subscriber logs:"
echo "    az containerapp logs show -g $RG -n $OS_APP --follow --type console"

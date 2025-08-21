# INTROSPECT 1 B

This lab demonstrates deploying two .NET 8 microservices (`ProductService` and `OrderService`) to Azure Container Apps with Dapr pub/sub using Azure Service Bus Topics.

See `scripts/deploy.sh` for full provisioning and deployment steps.

# Architecture (ACA + Dapr + Azure Service Bus)

![Architecture](Arc.png?raw=true "Architecture")

## Folder layout (inside the zip):

    1b-lab/
      ProductService/        # .NET 8 publisher
      OrderService/          # .NET 8 subscriber
      aca/pubsub-servicebus.yaml   # Dapr component (Azure Service Bus Topics)
      scripts/deploy.sh      # build, push & deploy script
      README.md              # quick start this file


Execute below comments in CLI for build and deployment:
`az login` and
`bash scripts/deploy.sh`


AUthor
Prathap Mathiyalagan
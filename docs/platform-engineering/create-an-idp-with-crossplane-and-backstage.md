---
sidebar_position: 2
title: Create an Internal Developer Platform with Crossplane and Backstage
description: Learn how to create an Internal Developer Platform using Crossplane and Backstage
---

## Objectives

In this lab you will learn how to create an Internal Developer Platform (IDP) on Azure Kubernetes Service (AKS) using Crossplane and Backstage.

### What is Backstage?

Backstage is an open platform for building developer portals. It provides a unified interface for developers to discover, manage, and operate their software components. Backstage allows teams to create a single source of truth for their software ecosystem, making it easier to navigate and understand the various services and tools available within an organization. You can find out more about Backstage at [https://backstage.io/](https://backstage.io/).

### What is Crossplane?

Crossplane is an open-source project that enables you to manage cloud resources using Kubernetes. It allows you to define and provision cloud infrastructure using Kubernetes-native APIs, making it easier to manage complex cloud environments. Crossplane provides a way to create a control plane for managing cloud resources, enabling you to use Kubernetes as a single control plane for your entire infrastructure. You can find out more about Crossplane at [https://crossplane.io/](https://crossplane.io/).

## Prerequisites

- An Azure subscription and an Azure account with the necessary permissions to create resources. You can create an account at [https://azure.microsoft.com](https://azure.microsoft.com).
- Azure CLI -- Download it from [https://docs.microsoft.com/en-us/cli/azure/install-azure-cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- kubectl -- Download it from [https://kubernetes.io/docs/tasks/tools/](https://kubernetes.io/docs/tasks/tools/)
- Helm -- Download it from [https://helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/)
- A GitHub account. You can get one at [https://github.com/signup](https://github.com/signup)

## Provision a Control Plane Cluster

The IDP will be deployed on a control plane cluster. In this lab, you will provision an Azure Kubernetes Service (AKS) cluster to serve as the control plane for your IDP.

### Set environment variables

Set the following environment variables to configure naming conventions for the Azure resources you will create. In this example the location is set to `westus3`, but you can change it to any Azure region of your choice. The resource group name, AKS cluster name, and other resources will be generated based on the `local_name` variable and a random suffix. This will make it easier to identify and manage the resources you create.

```bash
local_name=platformdemo
location=westus3
suffix=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 6 | tr '[:upper:]' '[:lower:]')
rg_name=rg-${local_name}-${suffix}
aks_name=aks-${local_name}-${suffix}
vnet_name="vnet-${local_name}-${suffix}"
vnet_cidr="10.0.0.0/8"
node_subnet_name="sn-node-${local_name}-${suffix}"
node_subnet_cidr="10.68.0.0/16"
pod_cidr="10.69.0.0/16"         # NOTE: Make sure this does not overlap with the VNet CIDR nor any subnet CIDR
owner_tag="owner=${local_name}"
environment="control-plane"
```

### Create a Resource Group

Before creating any resources in Azure, you will need to be logged into your Azure account. You can do this by running the following command:

```bash
az login
```

Use the the following Axure CLI command to create a resource group for the AKS cluster:

```bash
az group create \
--name $rg_name \
--location $location \
--tags ${owner_tag} 
```

### Create a virtual network and subnet for the AKS cluster

Deploying the bootstrap cluster in a virtual network (VNet) is a best practice. This allows you to control the network configuration and security settings for the cluster. You can create a VNet using the following commands:

```bash
vnet_name="vnet-${local_name}-${suffix}"

az network vnet create \
    --name $vnet_name \
    --resource-group ${rg_name} \
    --location $location \
    --address-prefix ${vnet_cidr} \
    --tags ${owner_tag} \
    --output none
```

Notice in the example how the environment variables are used to create the VNet name. This will help you identify the resources you create in Azure. The `--address-prefix` parameter specifies the address space for the VNet. You can change this to any valid CIDR block of your choice.

Next, you will create a subnet for the AKS cluster. The subnet will be used to deploy the AKS cluster and its resources. You can create a subnet using the following command:

```bash
node_subnet_name="sn-node-${local_name}-${suffix}"

az network vnet subnet create \
--name $node_subnet_name \
--resource-group $rg_name \
--vnet-name $vnet_name \
--address-prefix ${node_subnet_cidr} \
--service-endpoints Microsoft.Storage \
--output none
```

The `--service-endpoints` parameter specifies the service endpoints for the subnet. In this example, the `Microsoft.Storage` endpoint is used to allow access to Azure Storage services from the AKS cluster. You can add other service endpoints as needed. The `address-prefix` parameter specifies the address space for the subnet using the value of the `node_subnet_cidr` variable. You can change this to any valid CIDR block of your choice by changing the value of the variable.

### Create the bootstrap cluster on AKS

Now that you have created the resource group, VNet, and subnet, you can create the bootstrap cluster to host the IDP. You can do this using the following command:

```bash
az aks create \
    --name $aks_name \
    --resource-group $rg_name \
    --location $location \
    --node-count 3 \
    --enable-managed-identity \
    --enable-workload-identity \
    --enable-oidc-issuer \
    --network-plugin azure \
    --network-dataplane cilium \
    --network-plugin-mode overlay \
    --pod-cidr 10.69.0.0/16 \
    --vnet-subnet-id $node_subnet_id \
    --nodepool-name "systempool" \
    --node-vm-size Standard_D2s_v4 \
    --node-osdisk-size 30 \
    --os-sku Ubuntu \
    --generate-ssh-keys \
    --tags ${owner_tag} \
    --output none
```

The AKS cluster will take some time to be fully provisioned. You need to wait until the cluster's provisioning is complete before proceeding to the next step. You can check the status of the cluster using the following commands:

```bash
state=$(az aks show \
    --name $aks_name \
    --resource-group $rg_name \
    --query provisioningState -o tsv)
while [ "$state" != "Succeeded" ]; do
    echo -n -e "Waiting for AKS cluster $aks_name to be provisioned..."
    sleep 30
    state=$(az aks show \
        --name $aks_name \
        --resource-group $rg_name \
        --query provisioningState -o tsv)
done
echo "Created AKS cluster $aks_name"
```

When you see the message `Created AKS cluster $aks_name`, the cluster is ready to for the next step, which is to update the cluster system node pool with a taint that will prevent workloads from being scheduled on the system node pool. This is a best practice to ensure that the system node pool is only used for system workloads and not for user workloads.

```bash
az aks nodepool update \
    --name ${system_nodepool_name} \
    --cluster-name $aks_name \
    --resource-group $rg_name \
    --node-taints "CriticalAddonsOnly=true:NoSchedule" \
    --output none

if [ $? -ne 0 ]; then
    echo "Failed to update system node pool $system_nodepool_name"
    exit 1
fi
echo "Updated system node pool $system_nodepool_name"
```

Now add another nodepool to the cluster that will be used for user workloads. This nodepool will be used to run the workloads that you will deploy in the IDP. You can do this using the following command:

```bash
az aks nodepool add \
    --name ${user_nodepool_name} \
    --cluster-name $aks_name \
    --resource-group $rg_name \
    --node-count 3 \
    --node-vm-size Standard_D2s_v4 \
    --node-osdisk-size 30 \
    --os-sku Ubuntu \
    --enable-cluster-autoscaler \
    --min-count 1 \
    --max-count 10 \
    --output none

if [ $? -ne 0 ]; then
    echo "Failed to add user node pool $user_nodepool_name"
    exit 1
fi
echo "Added user node pool $user_nodepool_name"
```

In this example we are using the cluster autoscaler to automatically scale the nodepool based on the workload. You can change the `--min-count` and `--max-count` parameters to set the minimum and maximum number of nodes in the nodepool. The `--node-vm-size` parameter specifies the size of the VM used for the nodes in the nodepool. You can change this to any valid VM size of your choice.

### Connect to the AKS cluster

At this point you have created the AKS cluster and the nodepools. You can now connect to the AKS cluster using the following command:

```bash
az aks get-credentials \
    --name $aks_name \
    --resource-group $rg_name \
    --overwrite-existing
```

This command will configure your local `kubectl` context to use the AKS cluster. You can verify that you are connected to the cluster by running the following command:

```bash
kubectl get nodes
```

You should see a list of nodes in the cluster. If you see the nodes, you are connected to the AKS cluster and ready to proceed with the next steps.

## Install Components for the IDP

In this section, you will install the components needed to create the IDP. The components include Crossplane, Backstage, and ArgoCD.

### Install ArgoCD

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It allows you to manage your Kubernetes resources using Git repositories. You can install ArgoCD using the following command:

```bash
```

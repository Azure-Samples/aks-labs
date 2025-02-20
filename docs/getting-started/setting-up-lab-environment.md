---
title: "Setting up the Lab Environment"
description: "Setting up the lab environment for the workshops"
sidebar_label: "Setting up the Lab Environment"
sidebar_position: 1
authors:
 - "Russell de Pina"
 - "Paul Yu"
 - "Ken Kilty"
contacts:
 - "@russd2357"
 - "@paultdotyu"
 - "@KenKilty"
---

## Prerequisites

Before you begin, you will need an [Azure subscription](https://azure.microsoft.com/) with permissions to create resources and a [GitHub account](https://github.com/signup). Using a code editor like [Visual Studio Code](https://code.visualstudio.com/) will also be helpful for editing files and running commands.

### Command Line Tools

Many of the workshops on this site will be done using command line tools, so you will need to have the following tools installed:

- [Azure CLI](https://learn.microsoft.com/cli/azure/what-is-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Git](https://git-scm.com/)
- Bash shell (e.g. [Windows Terminal](https://www.microsoft.com/p/windows-terminal/9n0dx20hk701) with [WSL](https://docs.microsoft.com/windows/wsl/install-win10) or [Azure Cloud Shell](https://shell.azure.com))

If you are unable to install these tools on your local machine, you can use the Azure Cloud Shell, which has most of the tools pre-installed.

---

## Lab Environment Setup

Many of the workshops will require the use of multiple Azure resources such as:

- [Azure Log Analytics](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-overview)
- [Azure Managed Prometheus](https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-overview)
- [Azure Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/overview)
- [Azure Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview)
- [Azure Container Registry](https://learn.microsoft.com/azure/container-registry/container-registry-intro).

The resource deployment can take some time, so to expedite the process, we will use a [Bicep template](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview?tabs=bicep) to deploy those resources.

:::info[Important]

You must ensure the region where you choose to deploy supports [availability zones](https://learn.microsoft.com/azure/aks/availability-zones-overview) to demonstrate the concepts in the some of the workshops. You can list the regions that support availability zones using the following command:

```bash
az account list-locations --query "[?metadata.regionType=='Physical' && metadata.supportsAvailabilityZones==true].{Region:name}" -o table
```

:::

In this workshop, we will set environment variables for the resource group name and location. Run the following commands to set the environment variables.

```bash
export RG_NAME="myResourceGroup"
export LOCATION="eastus"
```

This will set the environment variables for the current terminal session. If you close the current terminal session, you will need to set the environment variables again.

Run the following command and follow the prompts to log in to your Azure account using the Azure CLI.

```bash
az login --use-device-code
```

:::tip

> If you are logging into a different tenant, you can use the **--tenant** flag to specify the tenant domain or tenant ID.

:::

Run the following command to create a resource group using the environment variables you just created.

```bash
az group create \
--name ${RG_NAME} \
--location ${LOCATION}
```

### Deploy Azure resources using Bicep

Run the following command to download the Bicep template file to deploy the lab resources *except* the AKS cluster which we will create in this workshop.

```bash
curl  -o main.bicep https://raw.githubusercontent.com/azure-samples/aks-labs/refs/heads/main/docs/storage/assets/main.bicep
```

Verify the contents of the **main.bicep** file by running the following command.

```bash
cat main.bicep
```

Run the following command to save your user object ID to a variable.

```bash
export USER_ID="$(az ad signed-in-user show --query id -o tsv)"
```

Run the following command to save the deployment name to a variable. In this example we set the deployment name to **labdemo**.

```bash
export DEPLOY_NAME="labdemo"
```

Run the following command to deploy Bicep template into the resource group.

```bash
az deployment group create \
--name ${DEPLOY_NAME} \
--resource-group $RG_NAME \
--template-file main.bicep \
--parameters userObjectId=${USER_ID} \
--no-wait
```

This deployment will take a few minutes to complete. Move on to the next section while the resources are being deployed.

### AKS Deployment Strategies

In this section, you will explore cluster setup considerations such as cluster sizing and topology, system and user node pools, and availability zones. You will create an AKS cluster implementing some of the best practices for production clusters. Not all best practices will be covered in this workshop, but you will have a good foundation to build upon.

#### Size Considerations

Before you deploy an AKS cluster, it's essential to consider its size based on your workload requirements. The number of nodes needed depends on the number of pods you plan to run, while node configuration is determined by the amount of CPU and memory required for each pod. As you know more about your workload requirements, you can adjust the number of nodes and the size of the nodes.

When it comes to considering the size of the node, it is important to understand the types of Virtual Machines (VMs) available in Azure; their characteristics, such as CPU, memory, and disk, and ultimate the SKU that best fits your workload requirements. See the [Azure VM sizes](https://learn.microsoft.com/azure/virtual-machines/sizes/overview) documentation for more information.

:::note

> In your Azure subscription, you will need to make sure to have at least 32 vCPU of Standard D series quota available to create multiple AKS clusters and accommodate node surges on cluster upgrades. If you don't have enough quota, you can request an increase. Check [here](https://docs.microsoft.com/azure/azure-portal/supportability/per-vm-quota-requests) for more information.

:::

#### System and User Node Pools

When an AKS cluster is created, a single node pool is created. The single node pool will run Kubernetes system components required to run the Kubernetes control plane. It is recommended to create a separate node pool for user workloads. This separation allows you to manage system and user workloads independently.

System node pools serve the primary purpose of hosting pods implementing the Kubernetes control plane, such as **kube-apiserver**, **coredns**, and **metrics-server** just to name a few. User node pools are additional pools of compute that can be created to host user workloads. User node pools can be created with different configurations than the system node pool, such as different VM sizes, node counts, and availability zones and are added after the cluster is created.

#### Resilience with Availability Zones

When creating an AKS cluster, you can specify the use of [availability zones](https://learn.microsoft.com/azure/aks/availability-zones) which will distribute control plane zones within a region. You can think of availability zones as separate data centers within a large geographic region. By distributing the control plane across availability zones, you can ensure high availability for the control plane. In an Azure region, there are typically three availability zones, each with its own power source, network, and cooling.

### Creating an AKS Cluster

Now that we have covered the basics of cluster sizing and topology, let's create an AKS cluster with multiple node pools and availability zones.

Before you create the AKS cluster, run the following command to install the aks-preview extension. This extension will allow you to work with the latest features in AKS some of which will be in preview.

```bash
az extension add --name aks-preview
```

:::info[Important]

Before creating the AKS cluster you need to decide on the Kubernetes version to use. It is recommended to use the latest version of Kubernetes available in the region you are deploying to. You can find the latest version of Kubernetes available in your region by running the following command:

```bash
export K8S_VERSION=$(az aks get-versions -l ${LOCATION} \
--query "reverse(sort_by(values[?isDefault==true].{version: version}, &version)) | [0] " \
-o tsv)
```

*If you are planning on doing the cluster upgrades workshop, you will want to use an older version of Kubernetes. To do this, simply specify an index value greater than 0 and less than 4 in the query above.*

:::

Run the following command to create an AKS cluster.

```bash
az aks create \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--location ${LOCATION} \
--tier standard \
--kubernetes-version ${K8S_VERSION} \
--os-sku AzureLinux \
--nodepool-name systempool \
--node-count 3 \
--zones 1 2 3 \
--load-balancer-sku standard \
--network-plugin azure \
--network-plugin-mode overlay \
--network-dataplane cilium \
--network-policy cilium \
--ssh-access disabled \
--enable-managed-identity \
--enable-acns \
--generate-ssh-keys
```

The command above will deploy an AKS cluster with the following configurations:

- Deploy the selected version of Kubernetes.
- Create a system node pool with 3 nodes spread across availability zones 1, 2, and 3. This node pool will be used to host Kubernetes control plane and AKS-specific components.
- Use standard load balancer to support traffic across availability zones.
- Use Azure CNI Overlay Powered By Cilium networking. This will give you the most advanced networking features available in AKS and gives great flexibility in how IP addresses are assigned to pods. Note the Advanced Container Networking Services (ACNS) feature is enabled and will be covered later in the workshop.
- Some best practice for production clusters:
  - Disable SSH access to the nodes to prevent unauthorized access
  - Enable a managed identity for passwordless authentication to Azure services

:::info[Important]

> Not all best practices are implemented in this workshop. For example, you will be creating an AKS cluster that can be accessible from the public internet. For production use, it is recommended to create a private cluster. You can find more information on creating a private cluster [here](https://docs.microsoft.com/azure/aks/private-clusters). Don't worry though, more best practices will be implemented as we progress through the workshop 😎

:::

Once the AKS cluster has been created, run the following command to connect to the cluster.

```bash
az aks get-credentials \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--overwrite-existing
```

### Adding a User Node Pool

As mentioned above, the AKS cluster has been created with a system node pool that is used to host system workloads. You will need to manually create a user node pool to host user workloads. This user node pool will be created with a single node but can be scaled up as needed. Also note that the VM SKU is specified here which can be changed to suit your workload requirements.

Run the following command to add a user node pool to the AKS cluster.

```bash
az aks nodepool add \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--mode User \
--name userpool \
--node-count 1 \
--node-vm-size Standard_DS2_v2 \
--zones 1 2 3
```

### Tainting the System Node Pool

Now that we have created a user node pool, we need to add a taint to the system node pool to ensure that the user workloads are not scheduled on it. A taint is a key-value pair that prevents pods from being scheduled on a node unless the pod has the corresponding toleration. You could taint nodes using the [kubectl taint](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#taint) command, but since AKS can scale node pools up and down, it is recommended to use the [--node-taints](https://learn.microsoft.com/azure/aks/use-node-taints) option from the Azure CLI to ensure the taint is applied to all nodes in the pool.

Run the following command to add a taint to the system node pool.

```bash
az aks nodepool update \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--name systempool \
--node-taints CriticalAddonsOnly=true:NoSchedule
```

This taint will prevent pods from being scheduled on the node pool unless they have a toleration for the taint. More on taints and tolerations can be found [here](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/).

### Enabling AKS Monitoring and Logging

Monitoring and logging are essential for maintaining the health and performance of your AKS cluster. AKS provides integrations with Azure Monitor for metrics and logs. Logging is provided by [container insights](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#enable-container-insights) which can send container logs to [Azure Log Analytics Workspaces](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-overview) for analysis. Metrics are provided by [Azure Monitor managed service for Prometheus](https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-overview) which collects performance metrics from nodes and pods and allows you to query using [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/) and visualize using [Azure Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/overview).

The Bicep template that was deployed earlier should be completed by now. All you need to do next is enable [metrics monitoring](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli) and on the cluster by linking the monitoring resources to the AKS cluster.

:::tip

The Bicep template has outputs defined so you can access the names and resource IDs of the monitoring resources. However, the outputs are stored as key-value pairs. You can use this scriplet to export the outputs as environment variables.

```bash
while IFS= read -r line; \
do echo "exporting $line"; \
export $line=$(az deployment group show -g ${RG_NAME} -n ${DEPLOY_NAME} --query "properties.outputs.${line}.value" -o tsv); \
done < <(az deployment group show -g $RG_NAME -n ${DEPLOY_NAME} --query "keys(properties.outputs)" -o tsv)
```

The output shows the names environment variables being exported so you can use them later and looks like this:

```text
exporting monitor_id
exporting grafana_id
exporting grafana_Name
exporting logs_id
exporting akv_id
exporting akv_name
exporting akv_url
exporting acr_id
exporting acr_server
```

:::

Run the following command to enable metrics monitoring on the AKS cluster.

```bash
az aks update \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--enable-azure-monitor-metrics \
--azure-monitor-workspace-resource-id ${monitor_id} \
--grafana-resource-id ${grafana_id} \
--no-wait
```

Run the following command to enable the monitoring addon which will enable logging to the Azure Log Analytics workspace from the AKS cluster.

```bash
az aks enable-addons \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--addon monitoring \
--workspace-resource-id ${logs_id} \
--no-wait
```

:::note

> More on full stack monitoring on AKS can be found [here](https://learn.microsoft.com/azure/azure-monitor/containers/monitor-kubernetes)

:::

### Deploying the AKS Store Demo Application

This workshop will have you implement features and test scenarios on the AKS cluster. To do this, you will need an application to work with. The [AKS Store Demo application](https://github.com/Azure-Samples/aks-store-demo) is a simple e-commerce application that will be used to demonstrate the advanced features of AKS.

The application has the following services:

| Service         | Description                                                        |
| --------------- | ------------------------------------------------------------------ |
| store-front     | Web app for customers to place orders (Vue.js)                     |
| order-service   | This service is used for placing orders (Javascript)               |
| product-service | This service is used to perform CRUD operations on products (Rust) |
| rabbitmq        | RabbitMQ for an order queue                                        |

Here is a high-level architecture of the application:

![AKS store demo architecture](./assets/aks-store-architecture.png)

Run the following command to create a namespace for the application.

```bash
kubectl create namespace pets
```

Run the following command to install the application in the **pets** namespace.

```bash
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/refs/heads/main/aks-store-quickstart.yaml -n pets
```

Verify the application was installed with the following command.

```bash
kubectl get all -n pets
```

The application uses a LoadBalancer service to allow access to the application UI. Once you have confirmed all the pods are deployed, run the following command to get the storefront service IP address.

```bash
kubectl get svc store-front -n pets
```

Copy the **EXTERNAL-IP** of the **store-front** service to your browser to access the application.

![AKS Store Demo sample app](assets/acns-pets-app.png)

:::note[Congratulations!]

You have now created an AKS cluster with some best practices in place such as multiple node pools, availability zones, and monitoring. You have also deployed an application to work with in the other workshops.

At this point, you can jump into any of the workshops and focus on the topics that interest you the most.

:::

---

---
title: Scaling Kubernetes Workloads with KEDA and Karpenter
sidebar_label: Scaling with KEDA and Karpenter
---

# Scaling Kubernetes Workloads with KEDA and Karpenter

## Overview

In this workshop you'll learn about the Kubernetes Event Driven Autoscaler (aka [KEDA](https://keda.sh)), as well as the AKS Node Auto Provisioner (aka [NAP](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli)). We'll deploy a sample application, and demonstrate how Keda allows you to scale Kubernetes workloads based on a vast list of potential scale trigger sources. We'll then learn about how Node Auto Provisioner leverages the capabilities established by the [Karpenter](https://karpenter.sh/) open source project, via the [Karpenter Provider for Azure](https://github.com/Azure/karpenter-provider-azure), to improve the node scaling behavior and flexibility of your AKS cluster.

## Objectives

After completing this workshop, you'll be able to:

- Deploy and AKS cluster with KEDA and Node Auto Provisioner (Karpenter) managed add-ons enabled
- Configure a KEDA ScaledObject to drive application deployment autoscaling
- Monitor KEDA scaling operations
- Configure a NodeClass and Nodepool to control node auto provisioning
- Monitor Node Auto Provisioner scaling operations

## Prerequisites

In this lab we'll be creating an AKS cluster that has both the Kubernetes Event Driven Autoscaler (KEDA) and Node Autoprovisioning (NAP/Karpenter) enabled. To use these features you'll need the following:
- [Azure subscription](https://azure.microsoft.com/)
- [Azure CLI](https://learn.microsoft.com/cli/azure/what-is-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- Bash shell (e.g. [Windows Terminal](https://www.microsoft.com/p/windows-terminal/9n0dx20hk701) with [WSL](https://docs.microsoft.com/windows/wsl/install-win10) or [Azure Cloud Shell](https://shell.azure.com))
- Optional bash tools: [watch](https://en.wikipedia.org/wiki/Watch_(command)) and [jq](https://jqlang.org/)

At the writing of this workshop, Node Auto Provisioning is still in preview. Once you've prepared the pre-requisites above, you'll need to enable the preview feature in the Azure Subscription, and install the Preview CLI using the following steps.

1. Select the target subscription

    ```bash
    # Set your subscription ID
    SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    az account set -s $SUBSCRIPTION_ID

    # Confirm you've selected the right subscription
    az account show -o table
    ```

2. Enable the preview feature on the subscription

    ```bash
    # Enable the preview
    az feature register --namespace "Microsoft.ContainerService" --name "NodeAutoProvisioningPreview"
    ```

    :::info
    Enabling the preview can take a few minutes. You can check the status with the command below.
    :::

    ```bash
    # Check the status until the 'RegistrationState' shows as 'Registered'
    az feature show --namespace "Microsoft.ContainerService" --name "NodeAutoProvisioningPreview"
    ```

    Finally, for the feature to apply on the target subscription, you need to re-register the Microsoft.ContainerService provider on the subscription. 

    ```bash
    # Refresh the provider registration
    az provider register --namespace Microsoft.ContainerService
    ```

3. Install the AKS preview extension in your Azure CLI

    ```bash
    # Add the aks-preview extension
    az extension add --name aks-preview

    # Refresh the extension in-case you already had it installed
    az extension update --name aks-preview
    ```

## Environment Preparation

For this workshop, we'll need an AKS cluster with both the KEDA and Node Auto Provisioner (NAP) managed add-ons enabled. We'll also enable Azure CNI in overlay mode with the Cilium dataplane, however those are not technically required. You can review the NAP requirements [here](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli#limitations).

```bash
# Prepare Environment Variables
RESOURCE_GROUP=WorkshopRG
LOCATION=eastus2
CLUSTER_NAME=workshopcluster

# Create the Azure Resource Group
az group create -n $RESOURCE_GROUP -l $LOCATION

# Create the AKS cluster with KEDA and NAP enabled
# This operation will take several minutes
az aks create \
--name $CLUSTER_NAME \
--resource-group $RESOURCE_GROUP \
--enable-keda \
--node-provisioning-mode Auto \
--network-plugin azure \
--network-plugin-mode overlay \
--network-dataplane cilium \
--generate-ssh-keys

# Now let's get the cluster access credentials
az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME
```

We'll also need an application we can use for scaling operations. For this we'll use the [AKS Store](https://learn.microsoft.com/en-us/samples/azure-samples/aks-store-demo/aks-store-demo/) sample application. This application provides a several moving parts that are excellent targets for autoscaling. The store also includes an 'All-in-One' deployment option, which makes installation simple.

![AKS Pet Store Architecture](assets/scaling-with-keda-and-karpenter-aks-store.png)

```bash
# Create the pet store namespace
kubectl create ns pets

# Deploy the pet store components to the pets namespace
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-all-in-one.yaml -n pets

# Check the deployment status
kubectl get all -n pets
```

Once all of the pods are in 'Running' state (1/1 Ready), and the Services are populated with their 'External-IP', you should be ready to move on to the next step.

:::info
You may see some restarts and errors while the pods come online. This is due to cross deployment dependencies and health checks. Just wait for all pods to be in a 'Running' state with 1/1 Ready containers in the pod, which may take a few minutes.
:::

```bash
# Get the store URL
echo "Pet Store URL: http://$(kubectl get svc store-front -n pets -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

## What is KEDA?

KEDA is the 'Kubernetes Event-Driven Autoscaler. Traditionally, in Kubernetes, you would manage deployment scaling with a [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) (aka HPA). HPA's are somewhat limited in their scaling triggers. The KEDA open source project was created to introduce a pluggable approach for scale triggers. This means that anyone can create a scaler and use that scaler in KEDA, and fortunately, the open source community has done just that. KEDA has [more than 50 scalers](https://keda.sh/docs/2.17/scalers/) enabled out of the box! This means that you can scale your workload based on info from MongoDB, RabbitMQ, MySQL, etc, etc.

KEDA works by watching the external triggers, identified in the scaler configuration via the ScaledObject definition, and then by driving a Horizontal Pod Autoscaler attached to the target deployment.

![How KEDA Works](assets/scaling-with-keda-and-karpenter-keda-arch%20.png)

## Setup the KEDA Scaler

When a customer submits an order that order is sent to the order service. This initial order creation is a pretty light weight activity, as it just creates a message in rabbitMQ for the order that needs to be processed. However, those orders will sit in the queue until a virtual worker picks them up. It makes sense for us to automatically scale the virtual worker based on the depth of the queue in RabbitMQ. 

Fortunately, KEDA provides a [scaler for RabbitMQ](https://keda.sh/docs/2.17/scalers/rabbitmq-queue/) that we can use. Let's configure a KEDA scaled object that will increase the number of virtual worker pods based on the depth of the orders queue in RabbitMQ. For this, we'll need a KEDA ScaledObject, but also the authentication configuration for that RabbitMQ instance.

:::info
You'll notice that in the below setup we need to base64 encode the RabbitMQ connection string. This is common to help minimize the risk or escape characters causing configuration issues. It IS NOT a security feature, as base64 encoding is not encryption.
:::


```bash
RABBITMQ_HOST="rabbitmq.pets.svc.cluster.local:15672"
RABBITMQ_USERNAME="username"
RABBITMQ_PASSWORD="password"
RABBITMQ_CONNECTION_STRING="http://${RABBITMQ_USERNAME}:${RABBITMQ_PASSWORD}@${RABBITMQ_HOST}"

RABBITMQ_CONNECTION_STRING_BASE64=$(echo -n "${RABBITMQ_CONNECTION_STRING}"|base64 -w 0)

cat << EOF > virtual-worker-scaler.yaml
apiVersion: v1
kind: Secret
metadata:
  name: rabbitmq-scaler-secret
  namespace: pets
data:
  host: ${RABBITMQ_CONNECTION_STRING_BASE64}
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: trigger-auth-rabbitmq-conn
  namespace: pets
spec:
  secretTargetRef:
    - parameter: host
      name: rabbitmq-scaler-secret
      key: host
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: virtual-worker-rabbitmq-scaledobject
  namespace: pets
spec:
  scaleTargetRef:
    name: virtual-worker
  minReplicaCount: 1
  pollingInterval: 60
  triggers:
  - type: rabbitmq
    metadata:
      protocol: http
      queueName: orders
      mode: QueueLength
      value: "10"
    authenticationRef:
      name: trigger-auth-rabbitmq-conn
EOF

# Apply the scaled object configuration
kubectl apply -f virtual-worker-scaler.yaml
```

## Test Scaling

Now that we have our scaled object, lets increase the number of virtual customers and see if KEDA responds to the increased order queue depth by adding replicas to the virtual worker deployment.

```bash
# Increase the virtual customer replica count
kubectl scale deployment virtual-customer -n pets --replicas=4

# You can keep an eye on the deployment with either of the following commands
kubectl get deployment,pods -n pets
kubectl get deploy -n pets -w
```

:::info
In this lab we will sometimes use the [watch](https://en.wikipedia.org/wiki/Watch_(command)) command. This is a great tool for re-running a command repeatedly, and typically provides more clear output than the built in kubectl watch flag (-w).
:::

```bash
# To watch the deployment update
watch kubectl get deployment,pods -n pets
```

In addition to the commands above, we can check out the Horizontal Pod Autoscaler(HPA) events. Since KEDA drives the HPA to managed scaling, we can tap into the event stream. We also may want to take a look at the RabbitMQ depth itself, which we can do using the following.

```bash
# Watch the HPA events
kubectl events -w -n pets --for hpa/keda-hpa-virtual-worker-rabbitmq-scaledobject

# Check the queue depth
kubectl exec rabbitmq-0 -n pets -- rabbitmqctl list_queues
```

Alternatively, if you prefer to use curl, in one terminal port forward to the rabbitmq service. In another terminal, curl the rabbitmq http endpoint. We'll pipe the output to jq to filter out the queue length, but you can just skip that if you don't have jq installed.

```bash
# port-forward to the rabbitmq http endpoint
kubectl port-forward svc/rabbitmq -n pets 15672:15672

# curl the rabbitmq http endpoint and filter the output with jq
curl -u username:password http://localhost:15672/api/queues/%2f/orders|jq '.backing_queue_status.len'
```

Great! You should now be seeing the virtual worker count adjusting based on the queue depth. The virtual worker count will likely be pretty close to the virtual customer count, as they process at pretty close to the same speed. Feel free to play around with the deployment replica count to see how the scaler responds.

## Node Auto Provisioner (NAP)/Karpenter

Now that we have a good sense of how KEDA works, lets have a look at Node Auto Provisioner (aka NAP) and what it is.

The [Karpenter](https://karpenter.sh/) project was developed to address some limitations in traditional Kubernetes infrastructure scaling. We now know that KEDA and the Horizontal Pod Autoscaler can be used to scale deployments in Kubernetes, but what happens if you don't have enough compute capacity to run those pods? Up until this point we relied on the [Cluster Autoscaler](https://learn.microsoft.com/en-us/azure/aks/cluster-autoscaler?tabs=azure-cli) and it's implementations for the various compute hosting providers. 

While the cluster autoscaler has served us well for years, it doesn't provide much fine grained control in scaling behavior, in particular what machine types are selected. For example, what if you want to autoscale targeting the most cost effective machine types possible. Cluster autoscaler had no way to handle that.

The Karpenter project introduced new mechanisms for creating node configuration definitions (NodeClasses) and node pool definitions (NodePools). These are combined with new capabilities around scheduling (ex. affinity and topology spread), provisioning best-fit compute, and Disruption (how nodes are terminated when they aren't needed).

Karpenter was developed as an open-source project, allowing development of compute provider specific implementations of this open-source project, like the open-source [Karpenter Provider for Azure](https://github.com/Azure/karpenter-provider-azure) which you can host in your AKS cluster. This made it easy for AKS to offer a managed experience for Karpenter via what AKS calls 'Node Auto-Provisioning'.


## Using NAP

First, so far we've been running on the default nodepool that was created for us when we created the cluster. That's not ideal, as it's intended to be the 'system' pool. We should really move everything over to a new 'user' mode pool. For more on system and user pools see the AKS documentation [here](https://learn.microsoft.com/en-us/azure/aks/use-system-pools?tabs=azure-cli). However, even though the default pool is a system pool, it doesn't have a [Kubernetes taint](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) applied to restrict the workloads that are allowed to start on the nodepool. We can apply the appropriate taint by updating the nodepool with the Azure CLI for AKS.

:::info
In the example below, we'll taint the system pool with 'CriticalAddonsOnly=true:NoExecute'. This is a pretty aggressive way to apply a taint, as the 'NoExecute' will evict any pods that don't tolerate the taint. This was for demo purposes. In the real world you would likely use CriticalAddonsOnly=true:NoSchedule, and then migrate workloads over more gracefully. You can read more about the options in the Kubernetes documentation [here](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/).
:::

```bash
# First make sure your environment variables are still set
RESOURCE_GROUP=WorkshopRG
CLUSTER_NAME=workshopcluster

# Get the default nodepool name. It should be nodepool1, but we'll confirm
DEFAULT_NODEPOOL_NAME=$(az aks nodepool list -g $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --query '[0].name' -o tsv)

# Now apply the CriticalAddonsOnly taint to the default nodepool
az aks nodepool update \
-g $RESOURCE_GROUP \
--cluster-name $CLUSTER_NAME \
-n $DEFAULT_NODEPOOL_NAME \
--node-taints CriticalAddonsOnly=true:NoExecute
```

While the above command runs, in another terminal window, you can use the following to watch the pods as they transition to the new nodes which NAP will create. The process will run as follows.

1. All pet store pods will be evicted from the system nodepool, as they don't have the 'CriticalAddonsOnly' toleration
2. Within a minute or two, NAP will start a new node with a name prefix of 'aks-default'
3. Once started, the pet store pods will start on the new node

You can monitor both the events raised by karpenter itself and the node and pod states to see NAP in action.

```bash
# Watch the events raised by karpenter
kubectl get events -A --field-selector source=karpenter -w

# watch the new node start and pods get scheduled
watch kubectl get nodes,pods -n pets -o wide
```

It's cool to see that NAP jumped in and made sure nodes were created for us and the pods got scheduled, but it did use the default profile. Let's have a look at that and see how we can create our own custom profile. Let's, for example, imagine that we're looking to minimize our power consumption for a new green compute policy, and move workloads to ARM based compute. Can we create a NAP profile that prioritizes ARM compute?

```bash
# Have a look at the NodePool definitions that ship with the NAP managed add-on
kubectl get nodepool
kubectl describe nodepool default

# Notice how the 'system-surge' nodepool uses the 'kubernetes.azure.com/mode' label to focus on system nodes.
kubectl describe nodepool system-surge
```

Let's create our own Nodepool profile for ARM. We'll use the [weight](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli#node-pool-weights) parameter to give ours a higher priority than the default. You can also have a look at the supported selectors [here](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli#sku-selectors-with-well-known-labels).

```bash
cat <<EOF > arm-nodepool-profile.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: arm-nodepool
spec:
  weight: 10
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1s
  template:
    spec:
      nodeClassRef:
        group: karpenter.azure.com
        kind: AKSNodeClass
        name: default
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values:
        - arm64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        - D
EOF

# Now apply the new arm nodepool profile and watch the shift
kubectl apply -f arm-nodepool-profile.yaml 
```

Within a couple minutes, you should see the following:

1. New ARM node comes online with a name prefix of 'aks-arm'
2. Pet store pod is moved from the 'aks-default' node to the 'aks-arm' node
3. The 'aks-default' node is removed from the cluster

Again, you can watch this process with the following commands. 

```bash
# Watch the events raised by karpenter
kubectl get events -A --field-selector source=karpenter -w

# You can also watch the new node start and pods get scheduled
watch kubectl get nodes,pods -n pets -o wide
```


:::info
You may see a second 'aks-arm' node come online and then get removed, as NAP figures out how much capacity is needed.
:::

That was pretty cool, but what about that 'nodeClassRef' section of the nodepool profile. What can we do with that? 

The nodeClassRef is a reference to a [NodeClass](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli#node-image-updates) definition, where we can define settings about the node, like the OS disk size or the OS version. Lets create our own NodeClass and update the Nodepool profile to reference our own class.

```bash
cat <<EOF > arm-nodepool-profile_v2.yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: default-azurelinux
  annotations:
    kubernetes.io/description: "General purpose AKSNodeClass for running Azure Linux nodes"
spec:
  imageFamily: AzureLinux
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: arm-nodepool
spec:
  weight: 10
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1s
  template:
    spec:
      nodeClassRef:
        group: karpenter.azure.com
        kind: AKSNodeClass
        name: default-azurelinux
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values:
        - arm64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        - D
EOF

# Apply the new profile with the new NodeClass
kubectl apply -f arm-nodepool-profile_v2.yaml
```

As we watch the nodes and pods, you should see the following:

1. New node comes online with the name prefix 'aks-arm', but this one has an 'OS-IMAGE' set to 'CBL-Mariner/Linux' (aka. Azure Linux)
2. Pods are moved from the old node to the new Azure Linux node
3. The old 'aks-arm' node on Ubuntu is removed. 


```bash
# Watch the events raised by karpenter
kubectl get events -A --field-selector source=karpenter -w

# You can also watch the new node start and pods get scheduled
watch kubectl get nodes,pods -n pets -o wide
```

## Conclusion

In this lab we walked through using the [Kuberentes Event Driven Autoscaler](https://keda.sh) to drive the replica count of an application based on an external trigger. In our case, we used the queue depth of a RabbitMQ queue to increase an application's replica count. This is an extremely powerful tool in managing how your application can scale, and KEDA provides an amazing list of [scalers](https://keda.sh/docs/2.17/scalers/) that you can tap into. It's also open source, so you can add your own!

Next, we took a look at the Karpenter project, and the Azure Provider for Karpenter, which is provided in AKS as the [Node Autoprovisioner](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli) managed add-on. We saw how you can use the built in NodeClass and NodePool profile to enable autoscaling, but also how you can create your own custom NodeClass and Nodepool profile based on your own requirements. In our example, we wanted to run an Azure Linux pool that used ARM based nodes.

Using these two tools together can give you amazing control over the was your application and your cluster handle scaling, and we only scratched the surface of the potential of these solutions!
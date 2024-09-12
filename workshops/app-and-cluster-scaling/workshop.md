---
published: true # Optional. Set to true to publish the workshop (default: false)
type: workshop # Required.
title: Application and Cluster Scaling with Azure Kubernetes Service (AKS) # Required. Full title of the workshop
short_title: Application and Cluster Scaling # Optional. Short title displayed in the header
description: This is a workshop for getting started with AKS which was originally delivered at Microsoft Build 2023 Pre-day Workshop (PRE03) # Required.
level: beginner # Required. Can be 'beginner', 'intermediate' or 'advanced'
authors: # Required. You can add as many authors as needed
  - "Phill Gibson"
contacts: # Required. Must match the number of authors
  - "@phillipgibson"
duration_minutes: 90 # Required. Estimated duration in minutes
tags: kubernetes, azure, aks # Required. Tags for filtering and searching
---

# Getting started

In this workshop, you will learn and understand techniques on how to scale your Azure Kubernetes Service (AKS) cluster to meet the needs of your deployed applications and workloads. Understanding the features and capabilities of scaling at each level of your infrastructure, will ensure a well architected design that can support your workloads througout thier lifecycle. The goal of this workshop is to cover the most common types of scaling methods available to you for your applications deployed on AKS. We will start with infrastructure scaling, based on hardware signals and then progress to more complex scaling scenarios that include capturing specific metrics from an application to determine if the application needs to be scaled on top of the infrastructure.

## Objectives

The objectives of this workshop are to:

- Introduce you to the scaling concepts for Azure Kubernetes Service
- Understand each scaling method and when to apply them
- Manually scaling the Azure Kubernetes Service infrastructure
- Automating the scaling of the Azure Kubernetes Service infrastructure
- Scaling applications using Horizontal Pod Autoscale (HPA)
- Scaling applications using KEDA

## Prerequisites

<div class="info" data-title="Info">

> This workshop was originally delivered in-person at Microsoft Build 2023 and a pre-configured lab environment was available for all attendees.

</div>

The lab environment was pre-configured with the following:

- [Azure Subscription](https://azure.microsoft.com/free)
- [Azure CLI](https://learn.microsoft.com/cli/azure/what-is-azure-cli?WT.mc_id=containers-105184-pauyu)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Git](https://git-scm.com/)
- Bash shell (e.g. [Windows Terminal](https://www.microsoft.com/p/windows-terminal/9n0dx20hk701) with [WSL](https://docs.microsoft.com/windows/wsl/install-win10) or [Azure Cloud Shell](https://shell.azure.com))

## Workshop instructions

When you see these blocks of text, you should follow the instructions below.

<div class="task" data-title="Task">

> This means you need to perform a task.

</div>

<div class="info" data-title="Info">

> This means there's some additional context.

</div>

<div class="tip" data-title="Tip">

> This means you should pay attention to some helpful tips.

</div>

<div class="warning" data-title="Warning">

> This means you should pay attention to some information.

</div>

<div class="important" data-title="Important">

> This means you should **_really_** pay attention to some information.

</div>

## Scaling your cluster

In a enterprise production environment, the demands and resource useage of your workloads running on Azure Kubernetes Service (AKS) can be dynamic and change frequently. If your application requires more resources from the cluster, the cluster could be impacted due to the lack of resources. One of the easiest ways to ensure your applications have enough resources from the cluster, is to scale your cluster to include more working nodes.

There are two ways to accomplish adding more nodes to your AKS cluster. You can manually scale out your cluster, or you can configure cluster autoscaler to automatically adjust to the demands of your application and automatically scale the number of nodes for you. We'll look at how you can do each.

### Manually scaling your cluster

Manually scaling your cluster give you the ability to add or remove additional nodes to the cluster at any point in time. Using manual scaling is good for dev/test and/or small production environments where reacting to changing workload utilization is not that important. In most production environments, you will want to set policies based on conditions to scale your cluster in a more automated fashion. Manually scaling you cluster gives you the ability to scale your cluster at the exact time you want, but your applications could potentially be in a degraded and/or offline state while the cluster is scaling up.

<div class="task" data-title="Task">

> Open the terminal and run the following command to view and get the name of the AKS node pools

```bash
az aks show --resource-group myResourceGroup --name myAKSCluster --query agentPoolProfiles
```

The following is a condensed example output from the previous command. We're focused on getting the name property from the output. The output should look similar to:

```bash
[
  {
    "count": 3,
    "maxPods": 250,
    "name": "systempool",
    "osDiskSizeGb": 30,
    "osType": "Linux",
    "vmSize": "Standard_DS2_v2"
  }
]
```

Using the previous output name property, we will now scale the cluster up.

<div class="task" data-title="Task">

> Scale the cluster up by adding one additional node

```bash
az aks scale --resource-group myResourceGroup --name myAKSCluster --node-count 4 --nodepool-name <your node pool name>
```

Scaling will take a few moments. You should see the scaling activity running in your terminal.

```bash
 | Running ..
```

Once the scaling up is complete, you should see something similar as the completion output below:

```bash
{
  "aadProfile": null,
  "addonProfiles": null,
  "agentPoolProfiles": [
    {
      "count": 4,
      "maxPods": 250,
      "name": "systempool",
      "osDiskSizeGb": 30,
      "osType": "Linux",
      "vmSize": "Standard_DS2_v2",
      "vnetSubnetId": null
    }
  ],
  [...]
}
```

Notice the count property increased.

We will now manually scale the cluster down by one node.

<div class="task" data-title="Task">

> Scale the cluster down by removing one additional node

```bash
az aks scale --resource-group myResourceGroup --name myAKSCluster --node-count 3 --nodepool-name <your node pool name>
```

### Automatically scaling your cluster

The more preferred method to scaling your cluster, would be to use the cluster autoscaler component. Using the cluster autoscaler component enables Kubernetes to watch for pods in your cluster that can't be scheduled because of resource contraints. When the cluster autoscaler detects issues, it scales up the number of nodes in the node pool to meet the application demands.

Another additional benefit of using the cluster autoscaler component is automatically scaling your cluster nodes down when there is a lack of activity as well. Cluster autoscaler will regularly checks nodes for a lack of running pods and scales down the number of nodes as needed.

## Scaling your app

As your app becomes more utilized, you'll need to scale it to handle the increased load. In AKS, you can scale your app by increasing the number of replicas in your deployment. The Kubernetes Horizontal Pod Autoscaler (HPA) will automatically scale your app based on CPU and/or memory utilization. But not all workloads rely on these metrics for scaling. If say, you need to scale your workload based on the number of items in a queue, HPA will not be sufficient.

This is where we take a different approach and deploy KEDA to scale our app. [KEDA is a Kubernetes-based Event Driven Autoscaler](https://keda.sh/). It allows you to scale your app on almost any metric available to track. If there is a metric that KEDA can can access to, it can scale based on it. Under the covers KEDA, looks at the metrics and your scaling rules and eventually creates a HPA to do the actual scaling.

The AKS add-on for KEDA has already been installed in your cluster.

### Setting request and limits

When scaling on a performance metric, we need to let Kubernetes know how much compute and memory resources to allocate for each pod. We do this by setting the `requests` and `limits` in our deployment. The `requests` are the minimum amount of resources that Kubernetes will allocate for each pod. The `limits` are the maximum amount of resources that Kubernetes will allocate for each pod. Kubernetes will use these values to determine how many pods to run based on the amount of resources available on the nodes in the cluster.

<div class="task" data-title="Task">

> Open the `azure-voting-app-deployment.yaml` file, find the empty `resources: {}` block and replace it with the following.

</div>

```yaml
resources:
  requests:
    cpu: 4m
    memory: 55Mi
  limits:
    cpu: 6m
    memory: 75Mi
```

<div class="info" data-title="Info">

> Setting resource requests and limits is a best practice and should be done for all your deployments.

</div>

Your `azure-voting-app-deployment.yaml` file should now look like this:

<details>
<summary>Click to expand code</summary>

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  creationTimestamp: null
  labels:
    app: azure-voting-db
  name: azure-voting-db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: azure-voting-db
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: azure-voting-db
    spec:
      containers:
        - image: postgres
          name: postgres
          resources:
            requests:
              cpu: 4m
              memory: 55Mi
            limits:
              cpu: 6m
              memory: 75Mi
          env:
            - name: POSTGRES_USER_FILE
              value: "/mnt/secrets-store/database-user"
            - name: POSTGRES_PASSWORD_FILE
              value: "/mnt/secrets-store/database-password"
          volumeMounts:
            - name: azure-voting-db-secrets
              mountPath: "/mnt/secrets-store"
              readOnly: true
            - name: azure-voting-db-data
              mountPath: "/var/lib/postgresql/data"
              subPath: "data"
      serviceAccountName: azure-voting-app-serviceaccount
      volumes:
        - name: azure-voting-db-secrets
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: azure-keyvault-secrets
        - name: azure-voting-db-data
          persistentVolumeClaim:
            claimName: pvc-azuredisk

status: {}
```

</details>

<div class="task" data-title="Task">

> Run the following command to deploy the updated manifest.

</div>

```bash
kubectl apply -f azure-voting-app-deployment.yaml
```

### Scaling with KEDA based on CPU utilization

<div class="task" data-title="Task">

> Create a new `azure-voting-app-scaledobject.yaml` manifest for KEDA. Here we will scale the application up when the CPU utilization is greater than 50%.

</div>

```yaml
cat <<EOF > azure-voting-app-scaledobject.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: azure-voting-app-scaledobject
spec:
  scaleTargetRef:
    name: azure-voting-app
  triggers:
    - type: cpu
      metricType: Utilization
      metadata:
        value: "50"
EOF
```

<div class="info" data-title="Info">

> The default values for minimum and maximum replica counts weren't included in our manifest above, but it will default to 0 and 100 respectively. In some cases, the minimum defaults to 1 so consult the documentation for the specific scaler you are using.

</div>

<div class="task" data-title="Task">

> Apply the manifest to create the ScaledObject.

</div>

```bash
kubectl apply -f azure-voting-app-scaledobject.yaml
```

<div class="task" data-title="Task">

> Run the following command to ensure the ScaledObject was created.

</div>

```bash
kubectl get scaledobject
```

<details>
<summary>Sample output</summary>

Wait until the `READY` column shows `True`

```text
NAME                            SCALETARGETKIND      SCALETARGETNAME    MIN   MAX   TRIGGERS   AUTHENTICATION   READY   ACTIVE   FALLBACK   AGE
azure-voting-app-scaledobject   apps/v1.Deployment   azure-voting-app               cpu                         True    True     Unknown    16s
```

</details>

### Load testing your app

Now that our app is enabled for autoscaling, let's generate some load on our app and watch KEDA scale our app.

We'll use the [Azure Load Testing](https://learn.microsoft.com/azure/load-testing/overview-what-is-azure-load-testing?WT.mc_id=containers-105184-pauyu) service to generate load on our app and watch KEDA scale our app.

<div class="task" data-title="Task">

> In the Azure Portal, navigate to your shared resource group and click on your Azure Load Testing resource.
>
> Click the **Quick test** button to create a new test. In the **Quick test** blade, enter your ingress IP as the URL.
>
> Set the number of virtual users to **250**, test duration to **240** seconds, and the ramp up time of **60**.
>
> Click the **Run test** button to start the test.

</div>

<div class="info" data-title="Information">

> If you are familiar with creating JMeter tests, you can also create a JMeter test file and upload it to Azure Load Testing.

</div>

![Azure Load Testing](assets/load-test-setup.png)

<div class="task" data-title="Task">

> As the test is running, run the following command to watch the deployment scale.

</div>

```bash
kubectl get deployment azure-voting-app -w
```

<div class="task" data-title="Task">

> In a different terminal tab, you can also run the following command to watch the Horizontal Pod Autoscaler reporting metrics as well.

</div>

```bash
kubectl get hpa -w
```

After a few minutes, you should start to see the number of replicas increase as the load test runs.

In addition to viewing your application metrics from the Azure Load Testing service, you can also view detailed metrics from your managed Grafana instance and/or Container Insights from the Azure Portal, so be sure to check that out as well.

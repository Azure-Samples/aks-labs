---
title: Expanding the platform capabilities with Kube Resource Orchestrator (kro)
sidebar: Expanding the platform capabilities with Kube Resource Orchestrator (kro)
---

# Expanding the platform capabilities with Kube Resource Orchestrator (kro)

In this module, we will explore `kro` (Kube Resource Orchestrator), an open-source project that simplifies full-stack deployments by providing a Kubernetes-native abstraction layer for managing both infrastructure and applications. With kro, you can expose and provision external resources through a consistent API, integrating them seamlessly into your GitOps workflows and Kubernetes automation.

---

## Objectives

- Understand how Kube Resource Orchestrator (kro) simplifies full-stack, declarative infrastructure management using Kubernetes-native APIs.
- Learn to define and manage external Azure resources (e.g., Resource Groups, AKS clusters) using ResourceGraphDefinition in `kro`.
- Integrate `kro` into your existing GitOps workflows alongside CAPZ and ASOv2, enabling end-to-end infrastructure automation.
- Build and deploy complex infrastructure compositions entirely through Kubernetes Custom Resources.

---

## Prerequisites

This module is part of a series. Before doing this lab you should've completed the [Platform Engineering lab using AKS, GitOps, CAPZ, and ASOv2](./aks-capz-aso.md).

1. Create a directory to store the artifacts for this lab:

```bash
mkdir -p ~/aks-labs/platform-engineering/using-kro
cd ~/aks-labs/platform-engineering/using-kro
```

2. Load the environment variables as defined in [Step 1: Create the AKS cluster](./aks-capz-aso.md#step-1-create-the-aks-cluster). 

```bash
source ~/aks-labs/platform-engineering/aks-capz-aso/.envrc
```

:::note
Your `.envrc` file should look similar to the following example, with your own Azure and AKS details filled in:

```bash
# Environment variables
export AZURE_SUBSCRIPTION_ID=<your-azure-subscription-id>
export AZURE_TENANT_ID=<your-azure-tenant-id>

# AKS
export AKS_CLUSTER_NAME="<your-aks-cluster-name>"
export RESOURCE_GROUP="<your-resource-group-name>"
export LOCATION="<your-azure-region>"
export MANAGED_IDENTITY_NAME="<your-managed-identity-name>"
export KUBECONFIG=${HOME}/<path-to-your-kubeconfig>
export AKS_OIDC_ISSUER_URL=<your-aks-oidc-issuer-url>
export AZURE_CLIENT_ID=<your-azure-client-id>
export PRINCIPAL_ID=<your-principal-id>
```
:::

---
### What is kro?

kro — [Kube Resource Orchestrator](https://kro.run/docs/overview) — is an open-source project that makes it easy to build a Kubernetes-native abstraction layer for full-stack deployments.

In typical Kubernetes environments, provisioning external resources often means dealing with a variety of custom APIs and operator-specific definitions. kro addresses this by letting you onboard those external resources and expose them through a consistent, native Kubernetes API layer.

### Why kro?

kro introduces a clean abstraction model that simplifies how infrastructure is managed, enabling better separation of concerns between platform and application layers.

Combined with tools we already used here, like CAPZ and ASO, kro becomes a powerful component for building and managing infrastructure declaratively within Kubernetes, bringing external resource provisioning into the same GitOps-driven workflows as native Kubernetes resources.

### Core concepts

Here is a brief overview of `kro`'s core concepts. Of immediate interest is the `ResourceGraphDefinition` (RDG) as it is our main building block.


| Concept                 | Description                                                                 |
|--------------------------|-----------------------------------------------------------------------------|
| ResourceGraphDefinition  | Blueprint defining resources and their relationships.                      |
| Schema                   | Input parameters users must supply and validate.                           |
| Resources                | External services or components represented as nodes in the graph.         |
| Directed Acyclic Graph   | Execution order built from resource dependencies (create/update/delete).    |
| Controller               | Watches definitions, builds the graph, and reconciles resource states.     |


### Step 1: Deploy kro

1. Install kro

```bash 
export KRO_VERSION=$(curl -sL \
  https://api.github.com/repos/kro-run/kro/releases/latest | \
  jq -r '.tag_name | ltrimstr("v")'
  )

helm install kro oci://registry.k8s.io/kro/charts/kro \
  --namespace kro \
  --create-namespace \
  --version=${KRO_VERSION}
```
2. Wait for the kro pod to be `Ready`

```bash
kubectl wait --for=condition=Ready pod --all -n kro --timeout=300s
```

Once kro is up and running, we should now be able to create our first Azure Resource.

### Step 2: Prepare the cluster

For this first example, we will simply create a new Azure Resource Group. For this, we have to do the following:

  a) Create a namespace in AKS for the resource group.

  b) Create an ASO identity on this new namespace - As before with the ASO example, this will be used by ASOv2 to perform actions against our Subscription in Azure.

  c) Create a new `ResourceGraphDefinition` with the `serviceoperator.azure.com/credential-from: aso-credentials` annotation.

  d) Deploy a new instance of our resource group (defined in the `ResourceGraphDefinition` on step c)

### Quick 'Hello World' example using `kro`

1. Create a namespace

```bash
# create a resource group namespace
kubectl create ns rg-kro-aks-labs
```

2. Create the ASO identity in the `rg-aks-labs` namespace

```bash
cat <<EOF> kro-aso-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
 name: aso-credentials
 namespace: rg-kro-aks-labs
stringData:
 AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
 AZURE_TENANT_ID: "$AZURE_TENANT_ID"
 AZURE_CLIENT_ID: "$AZURE_CLIENT_ID"
 USE_WORKLOAD_IDENTITY_AUTH: "true"
EOF
```
3. Apply the `kro-aso-credentials.yaml`

```bash
kubectl apply -f kro-aso-credentials.yaml
```

4. Create the new `ResourceGraphDefinition`

```bash
cat <<'EOF' > rgd.yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: azurecontainer.kro.run
spec:
  schema:
    apiVersion: v1alpha1
    kind: AzureResourceGroup
    spec:
      name: string | default=rg-kro-aks-labs
      namespace: string | default=default
      location: string | required=true
  resources:
  - id: resourcegroup
    template:
      apiVersion: resources.azure.com/v1api20200601
      kind: ResourceGroup
      metadata:
        name: ${schema.spec.name}
        namespace: ${schema.spec.namespace}
        annotations:
          serviceoperator.azure.com/credential-from: aso-credentials
      spec:
        location: ${schema.spec.location}
EOF
```

:::note
Note that this `ResourceGraphDefinition` includes an annotation for the aso-credentials. We are scoping the ASO permissions on this namespace and not globally. 
:::

5. Apply it:

```bash
kubectl apply -f rgd.yaml
```

You can check if the new `ResourceGraphDefinition` was deployed successfully and that it is now `Active` by running this command:

```bash
kubectl get resourcegraphdefinition.kro.run/azurecontainer.kro.run
```

Expect:

```bash
NAME                     APIVERSION   KIND                       STATE    AGE
azurecontainer.kro.run   v1alpha1     AzureContainerDeployment   Active   3m
```

:::info
`ResourceGraphDefinition` will create resources based on the CRDs presented in the AKS clusters. These CRDs were previously defined when we installed the capi-operator. For this lab, we have defined the following under the `--crd-pattern` flag: "resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;eventhub.azure.com/*;storage.azure.com/*". If the `ResourceGraphDefinition` state is Not Active, make sure you have defined the CRDs that it expects when the capi-operator/ASO was installed. You can also add more CRDs by modifying the `azureserviceoperator-controller-manager` deployment on the `azure-infrastructure-system` namespace.
:::

6. Create an instance of the Azure Resource Group as specified by the `ResourceGroupDefinition`

```bash
cat <<EOF> instance.yaml
apiVersion: kro.run/v1alpha1
kind: AzureResourceGroup
metadata:
  name: rg-kro-aks-labs
  annotations:
    serviceoperator.azure.com/credential-from: aso-credentials
spec:
  name: rg-kro-aks-labs
  namespace: rg-kro-aks-labs
  location: westus2
EOF
```

7. Apply it:

```bash
kubectl apply -f instance.yaml
```

8. Verify that the resource was created:

```bash
kubectl get -n rg-kro-aks-labs resourcegroups
```

Expect:

```bash
NAME              READY   SEVERITY   REASON      MESSAGE
rg-kro-aks-labs   True               Succeeded
```

You can also verify it using `az cli`:

```bash
 az group show -n rg-kro-aks-labs
```
Expect:

```bash
{
  "id": "/subscriptions/XXXXXX-XXXXXX-XXXX-XXXX-XXXXXXXXX/resourceGroups/rg-kro-aks-labs",
  "location": "westus2",
  "managedBy": null,
  "name": "rg-kro-aks-labs",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

To remove the resource group:

```bash
kubectl delete -n rg-kro-aks-labs resourceGroups/rg-kro-aks-labs
```

---

### End to end example using kro + ASO

As a final example, lets look at a scenario where a developer asks for an new AKS cluster using a new `ResourceGraphDefinition` named `AzureStoreDemoDeployment`. This will be deployed on a new namespace called `store-demo`. As before, we will create a new namespace as well as the `aso-credentials` scoped to the namespace:

1. Create the namespace

```bash
kubectl create ns store-demo
```

2. Create the `aso-credentials` secret on the namespace

```bash
cat <<EOF> kro-aks-store-demo.yaml
apiVersion: v1
kind: Secret
metadata:
 name: kro-aks-store-demo
 namespace: store-demo
stringData:
 AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
 AZURE_TENANT_ID: "$AZURE_TENANT_ID"
 AZURE_CLIENT_ID: "$AZURE_CLIENT_ID"
 USE_WORKLOAD_IDENTITY_AUTH: "true"
EOF
```

Apply it:

```bash
kubectl apply -f kro-aks-store-demo.yaml
```

3. Create a new `ResourceGraphDefinition`

```bash
cat << 'EOF' > rgd-aks-store.yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: azurestore.kro.run
spec:
  schema:
    apiVersion: v1alpha1
    kind: AzureStoreDemoDeployment
    spec:
      name: string | default=store-demo
      namespace: string | default=default
      location: string | required=true
  resources:
  # Resource Group
  - id: resourceGroup
    template:
      apiVersion: resources.azure.com/v1api20200601
      kind: ResourceGroup
      metadata:
        name: ${schema.spec.name}-rg
        namespace: ${schema.spec.namespace}
        annotations:
          serviceoperator.azure.com/credential-from: kro-aks-store-demo
      spec:
        location: ${schema.spec.location}

  # AKS Cluster
  - id: managedCluster
    template:
      apiVersion: containerservice.azure.com/v1api20231102preview
      kind: ManagedCluster
      metadata:
        name: ${schema.spec.name}-aks
        namespace: ${schema.spec.namespace}
        annotations:
          serviceoperator.azure.com/credential-from: kro-aks-store-demo
      spec:
        location: ${schema.spec.location}
        dnsPrefix: ${schema.spec.name}-dns
        agentPoolProfiles:
          - name: nodepool1
            count: 1
            vmSize: Standard_DS2_v2
            mode: System
        identity:
          type: SystemAssigned
        owner:
          name: ${resourceGroup.metadata.name}
EOF
```

2. Apply it

```bash
kubectl apply -f rgd-aks-store.yaml
```
3. Create an `AzureStoreDemoDeployment` file

```bash
cat <<EOF> aks-store-instance.yaml
apiVersion: kro.run/v1alpha1
kind: AzureStoreDemoDeployment
metadata:
  name: store-demo-instance
  namespace: store-demo
spec:
  location: westus3
  namespace: store-demo
EOF
```

Apply it:

```bash
kubectl apply -f aks-store-instance.yaml
```

This will trigger the creation of a new AKS cluster called `store-demo`. You can follow the cluster creation by using (a) the Azure Portal, (b) `azure cli` or (c) by using `kubectl` 

Check if the cluster is now running using `kubectl`:

```bash
kubectl get managedclusters
```

Expect:

```bash
NAME             READY   SEVERITY   REASON      MESSAGE
store-demo-aks   True               Succeeded
```

:::info
While the resources are being created in Azure, you would see the following message when running `kubectl get managedclusters`:

```bash
NAME             READY   SEVERITY   REASON        MESSAGE
store-demo-aks   False   Info       Reconciling   The resource is in the process of being reconciled by the operator
```
:::

With the cluster now up and running, we can then (1) add Argo CD to the cluster, which once operational, will (2) pull the AKS Store Demo and install it on the cluster.

Here are the consolidated steps:

1. Get the credentials to access the cluster
2. Install Argo CD

```bash
az aks get-credentials -n store-demo-aks -g store-demo-rg --file store-demo.config
export KUBECONFIG=store-demo.config
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

:::note
If you have been following the other 2 labs in this series, you should have a file already in place in `aks-labs/platform-engineering/aks-capz-aso/app-project-env/argocd-apps/aks-store/aks-store-argocd-app.yaml`. You can use that file, which was generated for the main Platform Engineering cluster or proceed with the creation of this new file that is tailored for the developer cluster. The reason we are using this new file here is to showcase that you can fully customize an argocd application into your developer level cluster.
:::

Once Argo CD is installed, we will create an Argo CD Application:

```bash
cat <<EOF> argoapps-aks-store-demo.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aks-store-demo
  namespace: argocd
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: aks-store
  source:
    repoURL: https://github.com/Azure-Samples/aks-store-demo.git
    targetRevision: main
    path: kustomize/base
    directory:
      recurse: false
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

Apply it:

```bash
kubectl apply -f argoapps-aks-store-demo.yaml
```

You should now be able to see your deployment:

```bash
kubectl get pod,svc -n aks-store
```

Expect:

```bash
 kubectl get pod,svc -n aks-store
NAME                                    READY   STATUS    RESTARTS        AGE
pod/makeline-service-586bb769df-p45w7   1/1     Running   1 (2m20s ago)   3m
pod/mongodb-0                           1/1     Running   0               2m59s
pod/order-service-6f6d8ff4f6-pkb5m      1/1     Running   0               2m59s
pod/product-service-65c7fc7bf-pmws5     1/1     Running   0               3m
pod/rabbitmq-0                          1/1     Running   0               2m59s
pod/store-admin-5845d94fdd-xm47d        1/1     Running   0               3m
pod/store-front-66ccf8d74d-v927p        1/1     Running   0               3m
pod/virtual-customer-7dbb957677-4cjsb   1/1     Running   0               3m
pod/virtual-worker-796f69dcfc-dn5t5     1/1     Running   0               3m

NAME                       TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)              AGE
service/makeline-service   ClusterIP      10.0.89.191    <none>         3001/TCP             3m
service/mongodb            ClusterIP      10.0.99.100    <none>         27017/TCP            3m
service/order-service      ClusterIP      10.0.187.197   <none>         3000/TCP             3m
service/product-service    ClusterIP      10.0.137.192   <none>         3002/TCP             3m
service/rabbitmq           ClusterIP      10.0.61.234    <none>         5672/TCP,15672/TCP   3m
service/store-admin        LoadBalancer   10.0.240.33    4.149.69.122   80:30725/TCP         3m
service/store-front        LoadBalancer   10.0.199.251   4.149.88.160   80:32556/TCP         3m
```

The AKS Store Demo should now be accessible through its public IP:

![AKS Store Demo](assets/aks-store-demo-frontend.png)

---

## Summary

In this lab, we accomplished the following:

- Using kro (Kube Resource Orchestrator), you have created a new AKS cluster, added Argo CD to this cluster and deployed the AKS Store Demo as an Argo CD Application.

### Key Takeaways

- **kro simplifies full-stack deployments** by providing a Kubernetes-native abstraction layer for managing both infrastructure and applications through **ResourceGraphDefinitions**.
- **ResourceGraphDefinitions enable declarative infrastructure** - Define complex resource compositions once and instantiate them multiple times with different parameters.
- **GitOps integration** - By combining kro with Argo CD, you can manage your entire infrastructure and application lifecycle from Git repositories.
- **Namespace-scoped credentials** - Using ASO credentials scoped to specific namespaces improves security and reduces blast radius.
- **Dependency management** - kro's directed acyclic graph (DAG) ensures resources are created and destroyed in the correct order based on their dependencies.

### Next Steps

- Explore more advanced ResourceGraphDefinitions that include networking, storage, and monitoring components
- Integrate kro ResourceGraphDefinitions into your GitOps workflows using Argo CD ApplicationSets for multi-environment deployments
- Implement custom ResourceGraphDefinitions for your organization's specific infrastructure patterns
- Review the [kro documentation](https://kro.run/docs) for additional capabilities and best practices
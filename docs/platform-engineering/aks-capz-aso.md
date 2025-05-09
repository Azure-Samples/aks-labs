---
title: Platform Engineering on AKS with GitOps, CAPZ, and ASO
sidebar: Platform Engineering on AKS
---

# Platform Engineering on AKS with GitOps, CAPZ, and ASO

Welcome to the **Platform Engineering on AKS** workshop. This hands-on workshop will guide you through implementing a robust platform engineering environment using the Cloud Native pattern on Azure Kubernetes Service (AKS). The environment leverages GitOps practices and integrates tools such as [ArgoCD](https://argo-cd.readthedocs.io/en/stable/), and the [Cluster API Provider for Azure (CAPZ)](https://github.com/kubernetes-sigs/cluster-api-provider-azure) along with [Azure Service Operator (ASO)](https://azure.github.io/azure-service-operator/). By the end of this workshop, participants will be able to deploy infrastructure and application environments using these tools.

---

## Objectives

- Provide a foundational understanding of key tools in the platform engineering space
- Build a control plane AKS cluster using Azure CLI
- Bootstrap GitOps with ArgoCD
- Demonstrate how CAPZ and ASO can provision infrastructure and Kubernetes clusters
- Show how to deploy application environments on both existing AKS clusters and newly created dedicated clusters

:::tip
If you have used Infrastructure as Code tools like `teraform` to create resources in Azure, you can use the `asoctl` tool to convert these Azure resources into ASO deployments. To find out more about `asoctl` take a look [here](https://azure.github.io/azure-service-operator/tools/). You can download `asoctl` [here](https://github.com/Azure/azure-service-operator/releases/tag/v2.13.0)
:::
---

## Prerequisites

- Azure Subscription
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) version 2.60.0 or later
- [kubectl](https://kubernetes.io/docs/tasks/tools/) version 1.28.9 or later
- [helm](https://github.com/helm/helm/releases) version v.3.17.0 or later

---

## Architecture Overview

This workshop uses the [GitOps Bridge Pattern](https://github.com/gitops-bridge-dev/gitops-bridge?tab=readme-ov-file) and the [Building a Platform Engineering Environment on Azure Kubernetes Service (AKS)](https://github.com/Azure-Samples/aks-platform-engineering) as a foundation:

- A control plane cluster is provisioned and bootstrapped with ArgoCD
- ArgoCD syncs platform addons via GitOps
- Cluster API Provider for Azure (CAPZ) is used for managing additional clusters

:::note

`CAPZ` or `Crossplane`? Before deploying this solution, take time to evaluate which control plane best fits your organization's needs. In this workshop, we’ll focus on `CAPZ` and `ASO`, but `Crossplane` is another viable option. To help you decide, we've outlined the key differences between them in this guide [how to choose your control plane provider](https://github.com/azure-samples/aks-platform-engineering/blob/main/docs/capz-or-crossplane.md).

:::

### Step 1: Create the AKS cluster

Before we begin lets create a new directory that can be a placeholder for all of our files created during this lab:

```bash
mkdir aks-labs
cd aks-labs
```

Next, proceed by declaring the following environment variables:

```bash
cat <<EOF> .envrc
# Environment variables
export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)

# AKS
export AKS_CLUSTER_NAME="aks-labs"
export RESOURCE_GROUP="rg-aks-labs"
export LOCATION="westus3"
export MANAGED_IDENTITY_NAME="akspe"

# Argo CD
export GITOPS_ADDONS_ORG="https://github.com/dcasati"
export GITOPS_ADDONS_REPO="gitops"
export GITOPS_ADDONS_BASEPATH="base/"
export GITOPS_ADDONS_PATH="bootstrap/control-plane/addons"
export GITOPS_ADDONS_REVISION="main"
EOF
```

Load the environment variables:

```bash
source .envrc
```

:::tip
Now that we have saved the environment variables, you can always reload these variables later if needed by running `source .envrc` on this directory.
:::

1. Create the resource group

```bash
# Create resource group
az group create --name ${RESOURCE_GROUP} --location ${LOCATION}
```

2. Create the AKS cluster:

```bash
az aks create \
  --name ${AKS_CLUSTER_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --enable-managed-identity \
  --node-count 3 \
  --generate-ssh-keys \
  --enable-oidc-issuer \
  --enable-workload-identity
```

3. Get the credentials to access the cluster:

```bash
az aks get-credentials \
  --name ${AKS_CLUSTER_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --file aks-labs.config
  ```
Use the `aks-labs.config` file this as your KUBECONFIG

```bash
export KUBECONFIG=$PWD/aks-labs.config
```

### Step 2: Create create an user-assigned managed identity for CAPZ

In this step, we will do the following:

* Create a user-assigned managed identity for CAPZ

* Assign it the `Contributor` role

* Create two federated identity credentials: `aks-labs-capz-manager-credential` and serviceoperator`

1. Create a user-assigned identity:

  ```bash
  export AKS_OIDC_ISSUER_URL=$(az aks show \
    --resource-group ${RESOURCE_GROUP} \
    --name ${AKS_CLUSTER_NAME} \
    --query "oidcIssuerProfile.issuerUrl" \
    -o tsv)
  
  az identity create \
    --name "${MANAGED_IDENTITY_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}"
  ```

2. Retrieve Azure Managed Identity Client and Principal IDs:

  ```bash
  export AZURE_CLIENT_ID=$(az identity show \
    --name "${MANAGED_IDENTITY_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query "clientId" -o tsv)

  export PRINCIPAL_ID=$(az identity show \
    --name "${MANAGED_IDENTITY_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query "principalId" -o tsv)
  ```

  Verify that these variables are not empty:

  ```bash
  echo "AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID"
  echo "AZURE_TENANT_ID: $AZURE_TENANT_ID"
  echo "AZURE_CLIENT_ID: $AZURE_CLIENT_ID"
  echo "PRINCIPAL_ID: $PRINCIPAL_ID"  
  ```

3. Assigning `Contributor` role to the identity:

  ```bash
  az role assignment create \
    --assignee "${PRINCIPAL_ID}" \
    --role "Contributor" \
    --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}"
  ```

4. Creating federated identity credential: **aks-labs-capz-manager-credential**

  ```bash
  az identity federated-credential create \
    --name "aks-labs-capz-manager-credential" \
    --identity-name "${MANAGED_IDENTITY_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --issuer "${AKS_OIDC_ISSUER_URL}" \
    --subject "system:serviceaccount:azure-infrastructure-system:capz-manager" \
    --audiences "api://AzureADTokenExchange"
  ```

5. Creating federated identity credential: **serviceoperator**

  ```bash
  az identity federated-credential create \
    --name "serviceoperator" \
    --identity-name "${MANAGED_IDENTITY_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --issuer "${AKS_OIDC_ISSUER_URL}" \
    --subject "system:serviceaccount:azure-infrastructure-system:azureserviceoperator-default" \
    --audiences "api://AzureADTokenExchange"
  ```

### Step 3: Install ArgoCD

1. Create a namespace for Argo CD and install it on the cluster:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

2. Verify that the Argo CD pods are up and running:

  ```bash
  kubectl get pods -n argocd -w
  ```

  Expected output:

  ```bash
  NAME                                    READY   STATUS
  argocd-application-controller-0         1/1     Running
  argocd-applicationset-controller-xxxxx  1/1     Running
  argocd-dex-server-xxxxx                 1/1     Running
  argocd-notifications-controller-xxxxx   1/1     Running
  argocd-redis-xxxxx                      1/1     Running
  argocd-repo-server-xxxxx                1/1     Running
  argocd-server-xxxxx                     1/1     Running
  ```

### Step 4: Access ArgoCD UI

1. Retrieve ArgoCD admin password

  ```bash
  kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}" ; echo
  ```

If no public IP is available:

  ```bash
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  ```

Access the UI at [https://localhost:8080](https://localhost:8080). The default username is `admin`.

![Argo CD Portal](assets/argoCD-UI.png)

After you successfully login, you should see the Argo CD Applications - which at this point are empty.

![Argo CD Applications](assets/argoCD-InitialUI.png)

### Step 5: Install Cluster API Provider for Azure (CAPZ)

This section walks you through installing **Cluster API Provider for Azure (CAPZ)** through the Cluster API Operator (capi-operator). This step is need in order to prepare your environment for provisioning AKS clusters using GitOps workflows.

Prerequisite: cert-manager

**cert-manager** is required for capi/capz/aso and it plays a critical role in automating the lifecycle of TLS certificates required for the communications between controllers, validating and mutating webhooks and the Kubernetes API server. Without cert-manager, a kubernetes operator would have to manually create, distribute and rotate these certificates, making for a very complex day-2 operations.

To install `cert-manager`:

```bash
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs (adjust the namespace if needed)
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --version v1.15.3  # Use the latest stable version
```

Verify that cert-manager was installed:

```bash
kubectl get pods -n cert-manager
```

Expect:

```bash

```

You are now ready to install the `capi-operator`.

1. Generate a `values` file for the capi-operator:

```bash
cat <<EOF> capi-operator-values.yaml
core:
  cluster-api:
    version: v1.9.6
infrastructure:
  azure:
    version: v1.19.2
addon:
  helm:
    version: v0.3.1
manager:
  featureGates:
    core:
      ClusterTopology: true
      MachinePool: true
additionalDeployments:
  azureserviceoperator-controller-manager:
    deployment:
      containers:
        - name: manager
          args:
            --crd-pattern: "resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;eventhub.azure.com/*;storage.azure.com/*"
EOF
```

2. Install the Cluster API Operator

  ```bash
  helm repo add capi-operator https://kubernetes-sigs.github.io/cluster-api-operator
  helm repo update
  helm install capi-operator capi-operator/cluster-api-operator \
    --create-namespace -n capi-operator-system \
    --wait \
    --timeout=300s \
    -f capi-operator-values.yaml
  ```

:::info
If you need to modify or reinstall the cluster-api-operator, you can do it so by running this command:

to upgrade/update the chart (e.g.: after modifying the `capi-operator-values.yaml` file):

```bash
  helm upgrade --install install capi-operator capi-operator/cluster-api-operator \
  --create-namespace -n capi-operator-system \
  --wait \
  --timeout=300s \
  -f capi-operator-values.yaml
```

to uninstall the chart:

```bash
helm uninstall capi-operator -n capi-operator-system
```

Helm doesn't remove all of the CRDs from the cluster and those would have to be removed manually.
:::

3. Verify the `CAPZ` Installation

  ```bash
  kubectl get pods -n azure-infrastructure-system
  ```

  Expected output:

  ```
  azureserviceoperator-controller-manager-xxxxx   1/1   Running
  capz-controller-manager-xxxxx                   1/1   Running
  ```

4. Generating a CAPZ `AzureClusterIdentity`

```bash
cat <<EOF> identity.yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureClusterIdentity
metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/sync-wave: "5"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
  labels:
    clusterctl.cluster.x-k8s.io/move-hierarchy: "true"
  name: cluster-identity
  namespace: azure-infrastructure-system
spec:
  allowedNamespaces: {}
  clientID: ${AZURE_CLIENT_ID}
  tenantID: ${AZURE_TENANT_ID}
  type: WorkloadIdentity
EOF
```

5. Applying `identity.yaml` to the cluster

  ```bash
  kubectl apply -f identity.yaml
  ```
---

### Sample 1: Create a new cluster as an Argo CD Application 

```bash
# setup some enviroment variables for the new cluster
export DEV_CLUSTER_NAME=dev-cluster
export DEV_CLUSTER_LOCATION=eastus
```

```bash
cat <<EOF> aks-argo-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: "${DEV_CLUSTER_NAME}"
  namespace: argocd
spec:
  project: default
  destination:
    namespace: default
    server: https://kubernetes.default.svc
  source:
    repoURL: 'https://mboersma.github.io/cluster-api-charts'
    chart: azure-aks-aso
    targetRevision: v0.4.2
    helm:
      valuesObject:
        clusterName: "${DEV_CLUSTER_NAME}"
        location: "${DEV_CLUSTER_LOCATION}"
        subscriptionID: "${AZURE_SUBSCRIPTION_ID}"
        clientID: "${AZURE_CLIENT_ID}"
        tenantID: "${AZURE_TENANT_ID}"
        authMode: "workloadidentity"
        kubernetesVersion: v1.30.10
        clusterNetwork: "overlay"
        managedMachinePoolSpecs:
          pool0:
            count: 1
            enableAutoScaling: true
            enableEncryptionAtHost: false
            enableFIPS: false
            enableNodePublicIP: false
            enableUltraSSD: false
            maxCount: 3
            minCount: 1
            mode: System
            osSKU: AzureLinux
            vmSize: Standard_DS2_v2
            type: VirtualMachineScaleSets
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: -1
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 10m
EOF
```

Apply it:

```bash
 envsubst < aks-argo-application.yaml | kubectl apply -f -
```
---

## Summary

In this lab, we accomplished the following:

- Created the AKS control plane cluster using the Azure CLI.
- Installed Argo CD and accessed its web UI.
- Bootstrapped the environment using GitOps principles.
- Installed Cluster API Provider for Azure (CAPZ) and Azure Service Operator (ASO) to enable infrastructure provisioning.
- Provisioned a workload cluster using Argo CD.
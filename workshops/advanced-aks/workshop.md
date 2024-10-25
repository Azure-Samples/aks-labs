---
published: true # Optional. Set to true to publish the workshop (default: false)
type: workshop # Required.
title: Advanced AKS and Day 2 Operations # Required. Full title of the workshop
short_title: Advanced AKS and Day 2 Operations # Optional. Short title displayed in the header
description: This is a workshop for advanced AKS scenarios and day 2 operations # Required.
level: intermediate # Required. Can be 'beginner', 'intermediate' or 'advanced'
authors: # Required. You can add as many authors as needed
  - "Paul Yu"
  - "Brian Redmond"
  - "Phil Gibson"
  - "Russell de Pina"
  - "Ken Kilty"
contacts: # Required. Must match the number of authors
  - "@pauldotyu"
  - "@chzbrgr71"
  - "@phillipgibson"
  - "@russd2357"
  - "@kenkilty"
duration_minutes: 180 # Required. Estimated duration in minutes
tags: kubernetes, azure, aks # Required. Tags for filtering and searching
wt_id: WT.mc_id=containers-147656-pauyu
---

## Overview

---

## Objectives

---

## Prerequisites

- Pre-provisioned AKS cluster
- Azure CLI
- kubectl
- Helm

---

## Cluster Sizing and Topology

- Multiple clusters
- Multitenancy
- Availability Zones

---

## Advanced Networking Concepts

### Azure Container Networking Services

### Istio Service Mesh

---

## Advanced Storage Concepts

### Azure Container Storage

---

## Advanced Security Concepts

### Workload Identity

Workloads deployed on an Azure Kubernetes Services (AKS) cluster require Microsoft Entra application credentials or managed identities to access Microsoft Entra protected resources, such as Azure Key Vault and Microsoft Graph. Microsoft Entra Workload ID integrates with the capabilities native to Kubernetes to federate with external identity providers.

This Workload Identity section of the lab will deploy an application workload onto AKS and use Workload Identity to allow the application to access a secret in Azure KeyVault.

To expedite the running of commands in this section, it is advised to create the following exported environment variables. Please update the values to what is appropriate for your environment, and then run the export commands in your terminal.

```bash
export RESOURCE_GROUP="myResourceGroup" \
export LOCATION="eastus" \
export CLUSTER_NAME="myAKSCluster" \
export SERVICE_ACCOUNT_NAMESPACE="default" \
export SERVICE_ACCOUNT_NAME="workload-identity-sa" \
export SUBSCRIPTION="$(az account show --query id --output tsv)" \
export USER_ASSIGNED_IDENTITY_NAME="myIdentity" \
export FEDERATED_IDENTITY_CREDENTIAL_NAME="myFedIdentity" \
export KEYVAULT_NAME="keyvault-workload-id" \
export KEYVAULT_SECRET_NAME="my-secret"
```

#### Limitations

Please be aware of the following limitations for Workload Identity

- You can have a maximum of [20 federated identity credentials](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-considerations#general-federated-identity-credential-considerations) per managed identity.
- It takes a few seconds for the federated identity credential to be propagated after being initially added.
- The [virtual nodes](https://learn.microsoft.com/en-us/azure/aks/virtual-nodes) add on, based on the open source project [Virtual Kubelet](https://virtual-kubelet.io/docs/), isn't supported.
- Creation of federated identity credentials is not supported on user-assigned managed identities in these [regions.](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-considerations#unsupported-regions-user-assigned-managed-identities)



#### Enable Workload Identity on an AKS cluster

> NOTE: If Workload Idenity is already enabled on your AKS cluster, you can skip this section.

To enable Workload Idenity on the AKS cluster, run the following command.

```bash
az aks update --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --enable-oidc-issuer --enable-workload-identity
```

This will take several moments to complete

```bash
 | Running ..
```

Once complete, you will see the following output.

```bash
...
  "oidcIssuerProfile": {
    "enabled": true,
    "issuerUrl": "https://eastus.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/11111111-1111-1111-1111-111111111111/"
  },
...
    "workloadIdentity": {
      "enabled": true
    }
...
```

> NOTE: Please take note of the OIDC Issuer URL. This URL will be used to bind the Kubernetes service account to the Managed Identity for the federated credential.

You can store the AKS OIDC Issuer URL using the following command.

```bash
export AKS_OIDC_ISSUER="$(az aks show --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" --output tsv)"
```

#### Create a Managed Identity

A Managed Identity is a account (identity) created in Microsoft Entra ID. These identities allows your application to leverage them to use when connecting to resources that support Microsoft Entra authenticaion. Applications can use managed identities to obtain Microsoft Entra tokens without having to manage any credentials.

Run the following command to create a Managed Identity.

```bash
az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --subscription "${SUBSCRIPTION}"
```

You should see the following output that will contain your environment specific attributes.

```bash
{
  "clientId": "00000000-0000-0000-0000-000000000000",
  "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/USER_ASSIGNED_IDENTITY_NAME",
  "location": "LOCATION",
  "name": "USER_ASSIGNED_IDENTITY_NAME",
  "principalId": "00000000-0000-0000-0000-000000000000",
  "resourceGroup": "RESOURCE_GROUP",
  "systemData": null,
  "tags": {},
  "tenantId": "00000000-0000-0000-0000-000000000000",
  "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
}
```

Capture your Managed Identity client ID with the following command.

```bash
export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' --output tsv)"
```

#### Create a Kubernetes Service Account

Create a Kubernetes service account and annotate it with the client ID of the managed identity created in the previous step. 

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${USER_ASSIGNED_CLIENT_ID}"
  name: "${SERVICE_ACCOUNT_NAME}"
  namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
EOF
```

You should see the following output.


```bash
serviceaccount/SERVICE_ACCOUNT_NAME created
```

#### Create the Federated Identity Credential

Call the az identity federated-credential create command to create the federated identity credential between the managed identity, the service account issuer, and the subject. For more information about federated identity credentials in Microsoft Entra, see [Overview of federated identity credentials in Microsoft Entra ID](https://learn.microsoft.com/graph/api/resources/federatedidentitycredentials-overview?view=graph-rest-1.0).

```bash
az identity federated-credential create --name ${FEDERATED_IDENTITY_CREDENTIAL_NAME} --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --issuer "${AKS_OIDC_ISSUER}" --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" --audience api://AzureADTokenExchange
```

You should see the following output specific to your environment.

```bash
{
  "audiences": [
    "api://AzureADTokenExchange"
  ],
  "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/USER_ASSIGNED_IDENTITY_NAME/federatedIdentityCredentials/FEDERATED_IDENTITY_CREDENTIAL_NAME",
  "issuer": "https://LOCATION.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/",
  "name": "FEDERATED_IDENTITY_CREDENTIAL_NAME",
  "resourceGroup": "RESOURCE_GROUP",
  "subject": "system:serviceaccount:default:SERVICE_ACCOUNT_NAM",
  "systemData": null,
  "type": "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials"
}
```

> NOTE: It takes a few seconds for the federated identity credential to propagate after it is added. If a token request is made immediately after adding the federated identity credential, the request might fail until the cache is refreshed. To avoid this issue, you can add a slight delay after adding the federated identity credential.

#### Deploy a Sample Application Utilizing Workload Identity

When you deploy your application pods, the manifest should reference the service account created in the Create Kubernetes service account step. The following manifest deploys the `busybox` image and shows how to reference the account, specifically the metadata\namespace and spec\serviceAccountName properties.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sample-workload-identity
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
  labels:
    azure.workload.identity/use: "true"  # Required. Only pods with this label can use workload identity.
spec:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}
  containers:
    - image: busybox
      name: busybox
      command: ["sh", "-c", "sleep 3600"]
EOF
```

You should see the following output.

```bash
pod/sample-workload-identity created
```

> IMPORTANT: Ensure that the application pods using workload identity include the label azure.workload.identity/use: "true" in the pod spec. Otherwise the pods will fail after they are restarted.

#### Create an Azure KeyVault and Deploy an Application to Access it.

The instructions in this step show how to access secrets, keys, or certificates in an Azure key vault from the pod. The examples in this section configure access to secrets in the key vault for the workload identity, but you can perform similar steps to configure access to keys or certificates.

The following example shows how to use the Azure role-based access control (Azure RBAC) permission model to grant the pod access to the key vault. For more information about the Azure RBAC permission model for Azure Key Vault, see [Grant permission to applications to access an Azure key vault using Azure RBAC](https://learn.microsoft.com/azure/key-vault/general/rbac-guide).

1. Create a key vault with purge protection and RBAC authorization enabled. You can also use an existing key vault if it is configured for both purge protection and RBAC authorization:

```bash
export KEYVAULT_RESOURCE_GROUP="myResourceGroup"
export KEYVAULT_NAME="myKeyVault"

az keyvault create --name "${KEYVAULT_NAME}" --resource-group "${KEYVAULT_RESOURCE_GROUP}" --location "${LOCATION}" --enable-purge-protection --enable-rbac-authorization
```

The will take a few moments to create the Azure KeyVault.

```bash
 | Running ..
```

Once completed, you will see a similar output.

```bash
{
  "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/KEYVAULT_NAME",
  "location": "LOCATION",
  "name": "KEYVAULT_NAME",
  "properties": {
    "accessPolicies": [],
    "createMode": null,
    "enablePurgeProtection": true,
    "enableRbacAuthorization": true,
    "enableSoftDelete": true,
    "enabledForDeployment": false,
    "enabledForDiskEncryption": null,
    "enabledForTemplateDeployment": null,
    "hsmPoolResourceId": null,
    "networkAcls": null,
    "privateEndpointConnections": null,
    "provisioningState": "Succeeded",
    "publicNetworkAccess": "Enabled",
    "sku": {
      "family": "A",
      "name": "standard"
    },
    "softDeleteRetentionInDays": 90,
    "tenantId": "00000000-0000-0000-0000-000000000000",
    "vaultUri": "https://KEYVAULT_NAME.vault.azure.net/"
  },
...
```

2. Assign yourself the RBAC Key Vault Secrets Officer role so that you can create a secret in the new key vault:

> IMPORTANT: Please use your Azure subscription login email as the "\<user-email\>" value.

```bash
export KEYVAULT_RESOURCE_ID=$(az keyvault show --resource-group "${KEYVAULT_RESOURCE_GROUP}" --name "${KEYVAULT_NAME}" --query id --output tsv)

az role assignment create --assignee "\<user-email\>" --role "Key Vault Secrets Officer" --scope "${KEYVAULT_RESOURCE_ID}"
```

Once completed, you will see a similar output.

```bash
{
  "condition": null,
  "conditionVersion": null,
  "createdBy": null,
...
```

3. Create a secret in the key vault:

```bash
export KEYVAULT_SECRET_NAME="my-secret"

az keyvault secret set --vault-name "${KEYVAULT_NAME}" --name "${KEYVAULT_SECRET_NAME}" --value "Hello\!"
```

```bash
...
  "contentType": null,
  "id": "https://KEYVAULT_NAME.vault.azure.net/secrets/my-secret/00000000000000000000000000000000",
  "kid": null,
  "managed": null,
  "name": "my-secret",
  "tags": {
    "file-encoding": "utf-8"
  },
  "value": "Hello\\!"
```

4. Assign the Key Vault Secrets User role to the user-assigned managed identity that you created previously. This step gives the managed identity permission to read secrets from the key vault:

```bash
export IDENTITY_PRINCIPAL_ID=$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query principalId --output tsv)

az role assignment create --assignee-object-id "${IDENTITY_PRINCIPAL_ID}" --role "Key Vault Secrets User" --scope "${KEYVAULT_RESOURCE_ID}" --assignee-principal-type ServicePrincipal
```
Once completed, you will see a similar output.

```bash
{
  "condition": null,
  "conditionVersion": null,
  "createdBy": null,
...
```

5. Create an environment variable for the key vault URL:

```bash
export KEYVAULT_URL="$(az keyvault show --resource-group ${KEYVAULT_RESOURCE_GROUP} --name ${KEYVAULT_NAME} --query properties.vaultUri --output tsv)"
```

6. Deploy a pod that references the service account and key vault URL:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sample-workload-identity-key-vault
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}
  containers:
    - image: ghcr.io/azure/azure-workload-identity/msal-go
      name: oidc
      env:
      - name: KEYVAULT_URL
        value: ${KEYVAULT_URL}
      - name: SECRET_NAME
        value: ${KEYVAULT_SECRET_NAME}
  nodeSelector:
    kubernetes.io/os: linux
EOF
```

```bash
pod/sample-workload-identity-key-vault created
```

To check whether all properties are injected properly by the webhook, use the kubectl describe command:

```bash
kubectl describe pod sample-workload-identity-key-vault | grep "SECRET_NAME:"
```

If successful, the output should be similar to the following.

```bash
SECRET_NAME:                 my-secret
```

To verify that pod is able to get a token and access the resource, use the kubectl logs command:

```bash
kubectl logs sample-workload-identity-key-vault
```

If successful, the output should be similar to the following.

```bash
I1025 15:02:38.958802       1 main.go:63] "successfully got secret" secret="Hello\\!"
I1025 15:03:39.006595       1 main.go:63] "successfully got secret" secret="Hello\\!"
I1025 15:04:39.055667       1 main.go:63] "successfully got secret" secret="Hello\\!"
```

### Secure Supply Chain

- Image Integrity
- Image Cleaner

---

## Advanced Monitoring Concepts

### Azure Managed Prometheus

- ServiceMonitor
- PodMonitor

### AKS Cost Analysis

---

## Cluster Update Management

### API Server upgrades

### Node image updates

### Maintenance windows

### Azure Fleet

https://learn.microsoft.com/azure/kubernetes-fleet/update-orchestration?tabs=azure-portal

---

## Summary

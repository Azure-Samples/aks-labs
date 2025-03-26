---
sidebar_label: Workload Identity
sidebar_position: 1
title: Workload Identity
---


## Objectives

Workloads deployed on an Azure Kubernetes Services (AKS) cluster require Microsoft Entra application credentials or managed identities to access Microsoft Entra protected resources, such as Azure Key Vault and Microsoft Graph. Microsoft Entra Workload ID integrates with the capabilities native to Kubernetes to federate with external identity providers.

In this lab, you will learn how to:

- Enable Workload Identity on an AKS cluster
- Create a managed identity
- Create a Kubernetes service account
- Create a federated identity credential
- Deploy a sample application utilizing Workload Identity
- Access secrets in Azure Key Vault with Workload Identity

## Prerequisites

To complete this lab, you will need an [Azure subscription](https://azure.microsoft.com/) with permissions to create resources and a [GitHub account](https://github.com/signup). Using a code editor like [Visual Studio Code](https://code.visualstudio.com/) will also be helpful for editing files and running commands.

You will also need to have the command line tools mentioned in Command Line Tools section [Setting Up the Lab Enviroment](../getting-started/setting-up-lab-environment#command-line-tools) installed.

If you do not already have an AKS cluster created in your subscription, you can create all the required infrastructure for this lab by running the [Setting Up the Lab Enviroment](../getting-started/setting-up-lab-environment) lab.

### Set Environment Variables

To make it easier to run the commands in the lab, use the following commands save the names of the resource group, Azure Key Vault and AKS cluster, and region you are using in environment variables.

```bash
export RG_NAME="myResourceGroup"
export AKS_NAME="myAKSCluster"
export LOCATION="eastus"
export AKV_NAME="myKeyVault"
```

In this example we are using the resource group name **myResourceGroup**, the region name **eastus** and the AKS cluster name **myAKSCluster**. Using the environment variables allows you to easily change the values in one place and have them used in all the commands.

## Enable Workload Identity and OpenID Connect (OIDC) on an AKS cluster

Use the following command to check your AKS cluster to see if Workload Identity is already enabled.

```bash
az aks show \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--query "securityProfile.workloadIdentity.enabled" \
--output tsv
```

Use the following command to check if the OIDC issuer is enabled on your AKS cluster.

```bash
az aks show \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--query "oidcIssuerProfile.enabled" \
--output tsv
```

If you need to enable Workload Identity and/or the OIDC issuer, run the following command to enable them on your AKS cluster.

```bash
--name ${AKS_NAME} \
--enable-oidc-issuer \
--enable-workload-identity
```

:::note

This will can take several moments to complete.

:::

### Get the OIDC Issuer URL

After the cluster has been updated, run the following command to get the OIDC Issuer URL and save it in an environment variable.

```bash
export AKS_OIDC_ISSUER="$(az aks show \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--query "oidcIssuerProfile.issuerUrl" \
--output tsv)"
```

## Create a Managed Identity

A Managed Identity is a account (identity) created in Microsoft Entra ID. These identities allows your application to leverage them to use when connecting to resources that support Microsoft Entra authentication. Applications can use managed identities to obtain Microsoft Entra tokens without having to manage any credentials.

Run the following command to save the name of the user-assigned managed identity to an environment variable.

```bash
export USER_ASSIGNED_IDENTITY_NAME="myIdentity"
```

Run the following command to create a Managed Identity.

```bash
az identity create \
--resource-group ${RG_NAME} \
--name ${USER_ASSIGNED_IDENTITY_NAME} \
--location ${LOCATION} \
```

You will need several properties of the managed identity for the next steps. Run the following commands to capture the details of the managed identity and save the values as environment variables.

```bash

export USER_ASSIGNED_CLIENT_ID="$(az identity show \
--resource-group ${RG_NAME} \
--name ${USER_ASSIGNED_IDENTITY_NAME} \
--output tsv)"
export USER_ASSIGNED_PRINCIPAL_ID="$(az identity show \
--name "${USER_ASSIGNED_IDENTITY_NAME}" \
--resource-group ${RG_NAME} \
--query "principalId" \
--output tsv)"
```

## Create a Kubernetes Service Account

Create a Kubernetes service account and annotate it with the client ID of the managed identity created in the previous step. This annotation is used to associate the managed identity with the service account.

Run the following command to save the name of the service account to an environment variable.

```bash
export SERVICE_ACCOUNT_NAME="workload-identity-sa"
```

The service account namespace should be the same as the namespace where your application pods will be deployed. Run the following command to save the name of the service account namespace to an environment variable. In this example, we are using the **default** namespace, but you can change it to any namespace you want.

```bash
export SERVICE_ACCOUNT_NAMESPACE="default"
```

Run the following command to create the service account and annotate it with the client ID of the managed identity.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${USER_ASSIGNED_CLIENT_ID}
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
EOF
```

## Create the Federated Identity Credential

Run the following command to save the name of the federated identity credential to an environment variable.

```bash
export FEDERATED_IDENTITY_CREDENTIAL_NAME="myFedIdentity"
```

Run the following command to create the federated identity credential which creates a link between the managed identity, the service account issuer, and the subject. For more information about federated identity credentials in Microsoft Entra, see [Overview of federated identity credentials in Microsoft Entra ID](https://learn.microsoft.com/graph/api/resources/federatedidentitycredentials-overview?view=graph-rest-1.0).

```bash
az identity federated-credential create \
--name ${FEDERATED_IDENTITY_CREDENTIAL_NAME} \
--identity-name ${USER_ASSIGNED_IDENTITY_NAME} \
--resource-group ${RG_NAME} \
--issuer ${AKS_OIDC_ISSUER} \
--subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}" \
--audience api://AzureADTokenExchange
```

:::note

It takes a few seconds for the federated identity credential to propagate after it is added. If a token request is made immediately after adding the federated identity credential, the request might fail until the cache is refreshed. To avoid this issue, you can add a slight delay after adding the federated identity credential.

:::

Assign the Key Vault Secrets User role to the user-assigned managed identity that you created previously. This step gives the managed identity permission to read secrets from the key vault.

```bash
az role assignment create \
--assignee-object-id "${USER_ASSIGNED_PRINCIPAL_ID}" \
--role "Key Vault Secrets User" \
--scope "${AKV_ID}" \
--assignee-principal-type ServicePrincipal
```

## Deploy a Sample Application Utilizing Workload Identity

When you deploy your application pods, the manifest should reference the service account created in the Create Kubernetes service account step. The manifest depicted here shows the reference to the service account in the pod template ```spec``` section.

:::warning[Important]

Ensure that the application pods using workload identity include the label **azure.workload.identity/use: "true"** in the pod template ```spec``` section. Otherwise the pods will fail after they are restarted.

:::

Run the following command to deploy a sample application that uses workload identity.

```bash
kubectl apply -f - <<EOF
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

## Access Secrets in Azure Key Vault with Workload Identity

Make sure the Azure account you are signed in on has the apprpriate privileges to create secrets in an Azure Key Vault. If so, run the following command to create a secret in the key vault.

```bash
az keyvault secret set \
--vault-name "${AKV_NAME}" \
--name "my-secret" \
--value "Hello\!"
```

Run the following command to deploy a pod that references the service account and key vault URL.

```bash
kubectl apply -f - <<EOF
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
        value: ${AKV_URL}
      - name: SECRET_NAME
        value: my-secret
  nodeSelector:
    kubernetes.io/os: linux
EOF
```

To check whether all properties are injected properly, use the ```kubectl describe``` command:

```bash
kubectl describe pod sample-workload-identity-key-vault -n ${SERVICE_ACCOUNT_NAMESPACE} | grep "SECRET_NAME:"
```

To verify that pod is able to get a token and access the resource, use the kubectl logs command:

```bash
kubectl logs -n ${SERVICE_ACCOUNT_NAMESPACE} sample-workload-identity-key-vault
```

You have successfully deployed a sample application that utilizes Workload Identity to access a secret in Azure Key Vault.

## Clean Up

To clean up the resources created in this lab, run the following command to delete the resource group and all its contents. If you want to use the resources again, you can skip this step.

```bash
az group delete \
--name ${RG_NAME} \
--yes \
--no-wait
```

This will delete the resource group and all its contents, including the AKS cluster, managed identity, and key vault.

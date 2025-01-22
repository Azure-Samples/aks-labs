---
sidebar_label: Workload Identity
sidebar_position: 1
title: Workload Identity
---


## Workload Identity

Workloads deployed on an Azure Kubernetes Services (AKS) cluster require Microsoft Entra application credentials or managed identities to access Microsoft Entra protected resources, such as Azure Key Vault and Microsoft Graph. Microsoft Entra Workload ID integrates with the capabilities native to Kubernetes to federate with external identity providers.

This Workload Identity section of the lab will deploy an application workload onto AKS and use Workload Identity to allow the application to access a secret in Azure KeyVault.

### Limitations

Please be aware of the following limitations for Workload Identity

- You can have a maximum of [20 federated identity credentials](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-considerations#general-federated-identity-credential-considerations) per managed identity.
- It takes a few seconds for the federated identity credential to be propagated after being initially added.
- The [virtual nodes](https://learn.microsoft.com/azure/aks/virtual-nodes) add on, based on the open source project [Virtual Kubelet](https://virtual-kubelet.io/docs/), isn't supported.
- Creation of federated identity credentials is not supported on user-assigned managed identities in these [regions.](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-considerations#unsupported-regions-user-assigned-managed-identities)

### Enable Workload Identity on an AKS cluster

To enable Workload Identity on the AKS cluster, run the following command.

```bash
az aks update \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--enable-oidc-issuer \
--enable-workload-identity
```

<div class="info" data-title="Note">

> This will can take several moments to complete.

</div>

After the cluster has been updated, run the following command to get the OIDC Issuer URL, save it to the .env file, and reload the environment variables.

```bash
cat <<EOF >> .env
AKS_OIDC_ISSUER="$(az aks show \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--query "oidcIssuerProfile.issuerUrl" \
--output tsv)"
EOF
source .env
```

### Create a Managed Identity

A Managed Identity is a account (identity) created in Microsoft Entra ID. These identities allows your application to leverage them to use when connecting to resources that support Microsoft Entra authentication. Applications can use managed identities to obtain Microsoft Entra tokens without having to manage any credentials.

Run the following command to set the name of the user-assigned managed identity, save it to the .env file, and reload the environment variables.

```bash
cat <<EOF >> .env
USER_ASSIGNED_IDENTITY_NAME="myIdentity"
EOF
source .env
```

Run the following command to create a Managed Identity.

```bash
az identity create \
--resource-group ${RG_NAME} \
--name ${USER_ASSIGNED_IDENTITY_NAME} \
--location ${LOCATION} \
```

You will need several properties of the managed identity for the next steps. Run the following command to capture the details of the managed identity, service account, save it to the .env file, and reload the environment variables.

```bash
cat <<EOF >> .env
USER_ASSIGNED_CLIENT_ID="$(az identity show \
--resource-group ${RG_NAME} \
--name ${USER_ASSIGNED_IDENTITY_NAME} \
--query "clientId" \
--output tsv)"
USER_ASSIGNED_PRINCIPAL_ID="$(az identity show \
--name "${USER_ASSIGNED_IDENTITY_NAME}" \
--resource-group ${RG_NAME} \
--query "principalId" \
--output tsv)"
SERVICE_ACCOUNT_NAMESPACE="default"
SERVICE_ACCOUNT_NAME="workload-identity-sa"
FEDERATED_IDENTITY_CREDENTIAL_NAME="myFedIdentity"
EOF
source .env
```

### Create a Kubernetes Service Account

Create a Kubernetes service account and annotate it with the client ID of the managed identity created in the previous step. This annotation is used to associate the managed identity with the service account.

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

### Create the Federated Identity Credential

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

<div class="info" data-title="Note">

> It takes a few seconds for the federated identity credential to propagate after it is added. If a token request is made immediately after adding the federated identity credential, the request might fail until the cache is refreshed. To avoid this issue, you can add a slight delay after adding the federated identity credential.

</div>

Assign the Key Vault Secrets User role to the user-assigned managed identity that you created previously. This step gives the managed identity permission to read secrets from the key vault.

```bash
az role assignment create \
--assignee-object-id "${USER_ASSIGNED_PRINCIPAL_ID}" \
--role "Key Vault Secrets User" \
--scope "${AKV_ID}" \
--assignee-principal-type ServicePrincipal
```

### Deploy a Sample Application Utilizing Workload Identity

When you deploy your application pods, the manifest should reference the service account created in the Create Kubernetes service account step. The following manifest deploys the **busybox** image and shows how to reference the account, specifically the metadata\namespace and spec\serviceAccountName properties.

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

<div class="important" data-title="Important">

> Ensure that the application pods using workload identity include the label **azure.workload.identity/use: "true"** in the pod spec. Otherwise the pods will fail after they are restarted.

</div>

### Access Secrets in Azure Key Vault with Workload Identity

The instructions in this step show how to access secrets, keys, or certificates in an Azure key vault from the pod. The examples in this section configure access to secrets in the key vault for the workload identity, but you can perform similar steps to configure access to keys or certificates.

The following example shows how to use the Azure role-based access control (Azure RBAC) permission model to grant the pod access to the key vault. For more information about the Azure RBAC permission model for Azure Key Vault, see [Grant permission to applications to access an Azure key vault using Azure RBAC](https://learn.microsoft.com/azure/key-vault/general/rbac-guide).

<div class="warning" data-title="Warning">

> At the beginning of this lab, you created an Azure Key Vault and you should have properties of the key vault in the .env file. If you don't have the properties set, go back to the top of the workshop and set the properties.

</div>

Run the following command to create a secret in the key vault.

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

To check whether all properties are injected properly by the webhook, use the kubectl describe command:

```bash
kubectl describe pod sample-workload-identity-key-vault | grep "SECRET_NAME:"
```

To verify that pod is able to get a token and access the resource, use the kubectl logs command:

```bash
kubectl logs sample-workload-identity-key-vault
```

Nice work! You have successfully deployed a sample application that utilizes Workload Identity to access a secret in Azure Key Vault. If you thought the process was too complex, you'll be happy to know that the AKS Service Connector is a relatively new feature that simplifies the process of accessing Azure services from your AKS cluster. Using the AKS Service Connector, many of the steps you performed in this exercise are automated. Be sure to check out the [AKS Service Connector documentation](https://learn.microsoft.com/azure/service-connector/how-to-use-service-connector-in-aks) to learn more.

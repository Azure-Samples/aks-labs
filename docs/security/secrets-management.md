---
title: Secrets Management
sidebar: Secrets Management
sidebar_label: "Secrets Management"
sidebar_position: 6
authors:
 - "Jeff Blanchard"
contacts:
 - "@jblaaa-codes-ms"
---

Welcome to this workshop on secrets management with AKS. The goal of this lab is to walk through several popular ways to manage secrets with AKS. Kubernetes allows you to create secrets out of the box. It does not however, provide an effective way to manage the complexities that are required for running Kubernetes in a production environment. There are several addons that we can install within our Kubernetes cluster to enhance the secrets management capabilities.

---

## Getting Started

In this lab we will start off by deploying a basic AKS cluster. We'll then walk through some basics of how to install the secret addons, and then walk through some basics to demonstrate their secret management capabilities.

You will need the following installed on the machine you perform this lab:

- WSL or a linux terminal emulator
- kubectl
- kubelogin
- azure cli
- helm

## Deploy our AKS cluster and lab dependencies

We'll create a resource group, deploy AKS into it with some basic settings. 

```bash
export RG_NAME="my-aks-rg"
export LOCATION="centralus" # Change this to a region that supports availability zones
export AKS_NAME="myakscluster"

# Create the Resource Group
az group create \
--name ${RG_NAME} \
--location ${LOCATION}

# Deploy the AKS cluster

AKS_NAME=$(az aks create \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--location ${LOCATION} \
--tier free \
--node-count 2 \
--node-vm-size Standard_B2s \
--enable-managed-identity \
--enable-workload-identity \
--enable-oidc-issuer \
--query name -o tsv)

```

Excellent. You should now have a basic cluster in the resource group. Let's log into it. We will also deploy stakater reloader which will help us with updating deployments when secrets are updated in the keyvault.

```bash

az aks get-credentials --resource-group ${RG_NAME} --name ${AKS_NAME} --overwrite-existing

# You may be prompted to log back in. Provide creds and then run this command
# which will return the running pods in the kube-system namespace

kubectl get pods -n kube-system

# Add the Stakater Helm repository
helm repo add stakater https://stakater.github.io/stakater-charts

# Update your Helm repositories
helm repo update

# Install Reloader
helm install reloader stakater/reloader \
  --namespace reloader \
  --create-namespace

# Verify the installation
kubectl get pods -n reloader 

```

After completing the above steps you should have a fully functioning AKS Cluster and ready to start the next steps.

Now we will install some dependencies that each of the labs will be dependent on:

- Key Vault
- Managed Identity
- Federated Credential

```bash

# Get AKS OIDC Issuer URL
export AKS_OIDC_ISSUER=$(az aks show \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create Key Vault
export KV_NAME="kv-secret-lab-${RANDOM}"
az keyvault create \
--name ${KV_NAME} \
--resource-group ${RG_NAME} \
--location ${LOCATION} \
--enable-rbac-authorization

# Create User Assigned Managed Identity
export MI_NAME="aks-secret-lab-mi"
az identity create \
--name ${MI_NAME} \
--resource-group ${RG_NAME} \
--location ${LOCATION}

# Get the MI Client ID and Principal ID
export MI_CLIENT_ID=$(az identity show \
--name ${MI_NAME} \
--resource-group ${RG_NAME} \
--query clientId -o tsv)

export MI_PRINCIPAL_ID=$(az identity show \
--name ${MI_NAME} \
--resource-group ${RG_NAME} \
--query principalId -o tsv)

# Get Key Vault Resource ID
export KV_ID=$(az keyvault show \
--name ${KV_NAME} \
--resource-group ${RG_NAME} \
--query id -o tsv)

# Assign Key Vault Secrets User role to the MI
az role assignment create \
--role "Key Vault Secrets User" \
--assignee-object-id ${MI_PRINCIPAL_ID} \
--assignee-principal-type ServicePrincipal \
--scope ${KV_ID}

# Get your current user object ID
export USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# Assign Key Vault Secrets Officer role to your user
az role assignment create \
--role "Key Vault Secrets Officer" \
--assignee-object-id ${USER_OBJECT_ID} \
--assignee-principal-type User \
--scope ${KV_ID}

# Create federated identity credential for workload identity
az identity federated-credential create \
--name "aks-secret-lab-federated-id" \
--identity-name ${MI_NAME} \
--resource-group ${RG_NAME} \
--issuer ${AKS_OIDC_ISSUER} \
--subject system:serviceaccount:secret-lab:secret-lab-sa \
--audience api://AzureADTokenExchange

# Create the Namespace and Service Account with the appropriate labels/annotations for workload identity

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: secret-lab
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-lab-sa
  namespace: secret-lab
  annotations:
    azure.workload.identity/client-id: "${MI_CLIENT_ID}"
  labels:
    azure.workload.identity/use: "true"
EOF

# Create Some Basic Secrets

# Create a secret for a database connection string
# WARNING: Do not use real credentials in lab or documentation examples.
# Replace 'your-password-here' with a secure password for your environment.
az keyvault secret set \
--vault-name ${KV_NAME} \
--name "db-connection-string" \
--value "Server=myserver.database.windows.net;Database=mydb;User Id=myuser;Password=your-password-here;"

az keyvault secret set \
--vault-name ${KV_NAME} \
--name "color" \
--value "blue"



```

## CSI Secrets Provider

The CSI Secrets Driver is one of the easiest of the secrets management tools to get started with on AKS. It can be installed via an AKS Addon command.

```Bash

## Install the CSI provider

az aks enable-addons \
--addons azure-keyvault-secrets-provider \
--enable-secret-rotation \
--rotation-poll-interval 1m \
--name ${AKS_NAME} \
--resource-group ${RG_NAME}

## Verify the pods are installed / running

kubectl get pods -n kube-system -l app=secrets-store-csi-driver

```

### Using the CSI Secrets Provider

In order to demonstrate the secret provider running on AKS we'll implement a basic deployment and we'll attach a secret as an environment variable.

```bash

# Create a SecretProviderClass to define which secrets to mount from Key Vault

# Deploy podinfo with CSI secrets mounted
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo-csi
  namespace: secret-lab
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: secret-lab-sa
      containers:
      - name: podinfo
        image: stefanprodan/podinfo:latest
        ports:
        - containerPort: 9898
        env:
        - name: DB_CONNECTION_STRING
          valueFrom:
            secretKeyRef:
              name: keyvault-secrets
              key: db-connection-string
        - name: PODINFO_UI_COLOR
          valueFrom:
            secretKeyRef:
              name: keyvault-secrets
              key: color
        volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets-store"
          readOnly: true
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "azure-keyvault-secrets"
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-keyvault-secrets
  namespace: secret-lab
spec:
  provider: azure
  secretObjects:
  - secretName: keyvault-secrets
    type: Opaque
    data:
    - objectName: db-connection-string
      key: db-connection-string
    - objectName: color
      key: color
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    clientID: "${MI_CLIENT_ID}"
    keyvaultName: "${KV_NAME}"
    tenantId: "$(az account show --query tenantId -o tsv)"
    objects: |
      array:
        - |
          objectName: db-connection-string
          objectType: secret
        - |
          objectName: color
          objectType: secret
EOF

```

Once the above commands are executed, you should see a running deployment. Let's verify the deployment and check the secrets:

```bash
# Check the deployment status
kubectl get deployment -n secret-lab podinfo-csi

# Check the pods
kubectl get pods -n secret-lab -l app=podinfo

# Get the pod name
POD_NAME=$(kubectl get pods -n secret-lab -l app=podinfo -o jsonpath='{.items[0].metadata.name}')

# Verify secrets are mounted as files
kubectl exec -n secret-lab ${POD_NAME} -- ls -la /mnt/secrets-store

# View the secret values from mounted files
kubectl exec -n secret-lab ${POD_NAME} -- cat /mnt/secrets-store/db-connection-string
kubectl exec -n secret-lab ${POD_NAME} -- cat /mnt/secrets-store/color

# Verify environment variables are populated from the Kubernetes secret
kubectl exec -n secret-lab ${POD_NAME} -- env | grep -E 'DB_CONNECTION_STRING|PODINFO_UI_COLOR'

# Or use podinfo's /env endpoint to see all environment variables
kubectl exec -n secret-lab ${POD_NAME} -- curl -s http://localhost:9898/env

```

Great, we now have demostrated the ability to attach secrets as environment variables and volume mounts using the CSI Provider. Let's see what happens when we rotate one of the secrets...

```bash

# set the color to orange
az keyvault secret set \
--vault-name ${KV_NAME} \
--name "color" \
--value "orange"

# watch the deployment for updates. you should see the pod restart after a short period of time after you have updated the secret in the keyvault!

kubectl get deployment -n secret-lab podinfo-csi --watch

# get the secrets on the pod and see if it updated!

POD_NAME=$(kubectl get pods -n secret-lab -l app=podinfo -o jsonpath='{.items[0].metadata.name}')

# Verify environment variable is updated with the new color you set!
kubectl exec -n secret-lab ${POD_NAME} -- env | grep -E 'PODINFO_UI_COLOR'

```

Awesome! We were able to demostrate that using a combination of the CSI Provider and Reloader. We also enabled a managed identity assigned specifically to the namespace of this workload. This provides principle of least privilege to the secrets. You can repeat the pattern for multiple applications running in seperate namespaces!

## Clean Up Time

Make sure you clean up your resources!

```Bash
az group delete --resource-group ${RG_NAME} --yes

```

## Kudos/Credits

* Special thanks to Stefan Prodan for his [PodInfo application](https://github.com/stefanprodan/podinfo) which helped us demonstrate this use case.
* Credit to [stakater/Reloader](https://github.com/stakater/Reloader) for helping with the secret reload process.
* [Azure Key Vault Provider for Secrets Store CSI Driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure)

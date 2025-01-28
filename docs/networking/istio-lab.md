---
sidebar_position: 2
sidebar_label: Istio Service Mesh
title: Istio Service Mesh
---

## Istio Service Mesh

<div class="important" data-title="Important">

> If you have implemented the CiliumNetworkPolicy manifests from the previous sections, you will need to remove them with the following command before proceeding with the Istio service mesh.
>
> ```bash
> kubectl delete ciliumnetworkpolicy -n pets --all
> ```

</div>

Istio is an open-source service mesh that layers transparently onto existing distributed applications. Istio’s powerful features provide a uniform and more efficient way to secure, connect, and monitor services. Istio enables load balancing, service-to-service authentication, and monitoring – with few or no service code changes. Its powerful control plane brings vital features, including:

- Secure service-to-service communication in a cluster with TLS (Transport Layer Security) encryption, strong identity-based authentication, and authorization.
- Automatic load balancing for HTTP, gRPC, WebSocket, and TCP traffic.
- Fine-grained control of traffic behavior with rich routing rules, retries, failovers, and fault injection.
- A pluggable policy layer and configuration API supporting access controls, rate limits, and quotas.
- Automatic metrics, logs, and traces for all traffic within a cluster, including cluster ingress and egress.

Istio is integrated with AKS as an addon and is supported alongside AKS.

<div class="info" data-title="Note">

> Please be aware that the Istio addon for AKS does not provide the full functionality of the Istio upstream project. You can view the current limitations for this AKS Istio addon [here](https://learn.microsoft.com/azure/aks/istio-about#limitations) and what is currently [Allowed, supported, and blocked MeshConfig values](https://learn.microsoft.com/azure/aks/istio-meshconfig#allowed-supported-and-blocked-meshconfig-values)

</div>

### Prerequisites

For this workshop, you will also need to install the following:

- [Hubble CLI](https://docs.cilium.io/en/stable/observability/hubble/setup/)

### Configure CA certificates

In the Istio-based service mesh addon for Azure Kubernetes Service, by default the Istio certificate authority (CA) generates a self-signed root certificate and key and uses them to sign the workload certificates. To protect the root CA key, you should use a root CA which runs on a secure machine offline.

In this lab, we will create our own root CA, along with an intermediate CA, and configure the Istio addon to issue intermediate certificates to the Istio CAs that run in each cluster. An Istio CA can sign workload certificates using the administrator-specified certificate and key, and distribute an administrator-specified root certificate to the workloads as the root of trust.

#### Clone the Istio Repo

To expedite the process of creating the necessary certificates needed, we will leverage the certificate tooling provided by the Istio open-source project.

In your terminal, run the following command to clone the Istio repository.

```bash
git clone https://github.com/istio/istio.git
```

##### Generate the Root and Intermediate CA certificates

Navigate into the recently cloned Istio directory.

```bash
cd istio
```

Once in the **istio** directory, create the **akslab-certs** directory and navigate into it.

```bash
mkdir -p akslab-certs
pushd akslab-certs
```

Generate the root certificate and key.

```bash
make -f ../tools/certs/Makefile.selfsigned.mk root-ca
```

Generate the intermediate certificate and key

```bash
make -f ../tools/certs/Makefile.selfsigned.mk intermediate-cacerts
```

This will create a directory called **intermediate** which will contain the intermediate CA certificate information.

### Add the CA Certificates to Azure Key Vault

We will utilize Azure KeyVault to store the root and intermediate CA certificate information.

In the **akslab-certs** directory, run the following commands.

```bash
az keyvault secret set --vault-name ${AKV_NAME} --name istio-root-cert --file root-cert.pem
az keyvault secret set --vault-name ${AKV_NAME} --name istio-intermediate-cert --file ./intermediate/ca-cert.pem
az keyvault secret set --vault-name ${AKV_NAME} --name istio-intermediate-key --file ./intermediate/ca-key.pem
az keyvault secret set --vault-name ${AKV_NAME} --name istio-cert-chain --file ./intermediate/cert-chain.pem
```

### Enable Azure Key Vault provider for Secret Store CSI Driver for your cluster

The Azure Key Vault provider for Secrets Store CSI Driver allows for the integration of an Azure Key Vault as a secret store with an Azure Kubernetes Service (AKS) cluster via a [CSI volume](https://kubernetes-csi.github.io/docs/).

This integration will allow AKS to create, store, and retrieve Kubernetes secrets from Azure Key Vault.

Run the following command to enable the AKS Azure Key Vault secrets provider.

```bash
az aks enable-addons \
--addons azure-keyvault-secrets-provider \
--resource-group ${RG_NAME} \
--name ${AKS_NAME}
```

### Authorize the user-assigned managed identity of the AKS Azure Key Vault provider add-on to have access to Azure Key Vault

<div class="info" data-title="Note">

> For the purposes of this lab, we are using the **Key Vault Administrator** role. Please consider a role with lesser privileges for accessing Azure Key Vault in a production environment.

</div>

When you enable the Azure Key Vault provider for the AKS cluster, a user-assigned managed identity is created for the cluster. We will provide the managed identity with access to Azure Key Vault to retrieve the CA certificate information needed when we deploy the AKS Istio addon.

Run the following commands to add an Azure role assignment for Key Vault administrator for the add-on's user-assigned managed identity.

```bash
OBJECT_ID=$(az aks show \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--query 'addonProfiles.azureKeyvaultSecretsProvider.identity.objectId' \
-o tsv)

az role assignment create \
--role "Key Vault Administrator" \
--assignee-object-id ${OBJECT_ID} \
--assignee-principal-type ServicePrincipal \
--scope ${AKV_ID}
```

### Deploy Istio service mesh add-on with plug-in CA certificates

Before deploying the AKS Istio add-on, check the revision of Istio to ensure it is compatible with the version of Kubernetes on the cluster. To check the available revisions in the region that the AKS cluster is deployed in, run the following command:

```bash
az aks mesh get-revisions \
--location ${LOCATION} \
--output table
```

You should see the available revisions for the AKS Istio add-on and the compatible versions of Kubernetes they support.

Run the following command to enable the default supported revision of the AKS Istio add-on for the AKS cluster, using the CA certificate information created earlier.

```bash
az aks mesh enable \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--key-vault-id ${AKV_ID} \
--root-cert-object-name istio-root-cert \
--ca-cert-object-name istio-intermediate-cert \
--ca-key-object-name istio-intermediate-key \
--cert-chain-object-name istio-cert-chain
```

<div class="info" data-title="Note">

> This may take several minutes to complete.

</div>

Once the service mesh has been enabled, run the following command to view the Istio pods on the cluster.

```bash
kubectl get pods -n aks-istio-system
```

### Enable Sidecar Injection

Service meshes traditionally work by deploying an additional container within the same pod as your application container. These additional containers are referred to as a sidecar or a sidecar proxy. These sidecar proxies receive policy and configuration from the service mesh control plane, and insert themselves in the communication path of your application to control the traffic to and from your application container.

The first step to onboarding your application into a service mesh, is to enable sidecar injection for your application pods. To control which applications are onboarded to the service mesh, we can target specific Kubernetes namespaces where applications are deployed.

<div class="info" data-title="Note">

> For upgrade scenarios, it is possible to run multiple Istio add-on control planes with different versions. The following command enables sidecar injection for the Istio revision **asm-1-22**. If you are not sure which revision is installed on the cluster, you can run the following command `az aks show --resource-group ${RG_NAME} --name ${AKS_NAME}  --query "serviceMeshProfile.istio.revisions"`

</div>

The following command will enable the AKS Istio add-on sidecar injection for the **pets** namespace for the Istio revision **1.22**.

```bash
kubectl label namespace pets istio.io/rev=asm-1-22
```

At this point, we have simply just labeled the namespace, instructing the Istio control plane to enable sidecar injection on new deployments into the namespace. Since we have existing deployments in the namespace already, we will need to restart the deployments to trigger the sidecar injection.

Get a list of all the current pods running in the **pets** namespace.

```bash
kubectl get pods -n pets
```

You'll notice that each pod listed has a **READY** state of **1/1**. This means there is one container (the application container) per pod. We will restart the deployments to have the Istio sidecar proxies injected into each pod.

Restart the deployments for the **order-service**, **product-service**, and **store-front**.

```bash
kubectl rollout restart deployment order-service -n pets
kubectl rollout restart deployment product-service -n pets
kubectl rollout restart deployment store-front -n pets
```

If we re-run the get pods command for the **pets** namespace, you will notice all of the pods now have a **READY** state of **2/2**, meaning the pods now include the sidecar proxy for Istio. The RabbitMQ for the AKS Store application is not a Kubernetes deployment, but is a stateful set. We will need to redeploy the RabbitMQ stateful set to get the sidecar proxy injection.

```bash
kubectl rollout restart statefulset rabbitmq -n pets
```

If you again re-run the get pods command for the **pets** namespace, we'll see all the pods with a **READY** state of **2/2**

```bash
kubectl get pods -n pets
```

### Verify the Istio Mesh is Controlling Mesh Communications

We will walk through some common configurations to ensure the communications for the AKS Store application are secured. To begin we will deploy a Curl utility container to the cluster, so we can execute traffic commands from it to test out the Istio mesh policy.

Use the following command to deploy a test pod that will run the **curl** image to the **default** namespace of the cluster.

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: curl-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: curl
  template:
    metadata:
      labels:
        app: curl
    spec:
      containers:
      - name: curl
        image: curlimages/curl
        command: ["sleep", "3600"]
EOF
```

We can verify the deployment of the test pod in the **default** namespace using following command:

```bash
kubectl get pods -n default
```

Wait for the test pod to be in a **Running** state.

#### Configure mTLS Strict Mode for the pets namespace

Currently Istio configures managed workloads to use mTLS when calling other workloads, but the default permissive mode allows a service to accept traffic in both plaintext or mTLS traffic. To ensure that the workloads we manage with the Istio add-on only accept mTLS communication, we will deploy a Peer Authentication policy to enforce only mTLS traffic for the workloads in the **pets** namespace.

Prior to deploying the mTLS strict mode, let's verify that the **store-front** service will respond to a client not using mTLS. We will invoke a call from the test pod to the **store-front** service and see if we get a response.

Run the following command to get the name of the test pod.

```bash
CURL_POD_NAME="$(kubectl get pod -l app=curl -o jsonpath="{.items[0].metadata.name}")"
```

Run the following command to run a curl command from the test pod to the **store-front** service.

```bash
kubectl exec -it ${CURL_POD_NAME} -- curl -IL store-front.pets.svc.cluster.local:80
```

You should see a response with a status of **HTTP/1.1 200 OK** indicating that the **store-front** service successfully responded to the client Let's now apply the Peer Authentication policy that will enforce all services in the **pets** namespace to only use mTLS communication.

Run the following command to configure the mTLS Peer Authentication policy.

```bash
kubectl apply -n pets -f - <<EOF
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: pets-default
  namespace: pets
spec:
  mtls:
    mode: STRICT
EOF
```

Once the mTLS strict mode peer authentication policy has been applied, we will now see if we can again get a response back from the **store-front** service from a client not using mTLS. Run the following command to curl to the **store-front** service again.

```bash
kubectl exec -it ${CURL_POD_NAME} -- curl -IL store-front.pets.svc.cluster.local:80
```

Notice that the curl client failed to get a response from the **store-front** service. The error returned is the indication that the mTLS policy has been enforced, and that the **store-front** service has rejected the non mTLS communication from the test pod.

To verify that the **store-front** service is still accessible for pods in the **pets** namespace where the mTLS Peer Authentication policy is deployed, we will again deploy the **curl** image utility pod in the **pets** namespace. That pod will automatically get the sidecar injection of the Istio proxy, along with the policy that will enable it to securely communicate to the **store-front** service.

Use the following command to deploy the test pod that will run the **curl** image to the **pets** namespace of the cluster.

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: curl-pets-deployment
  namespace: pets
spec:
  replicas: 1
  selector:
    matchLabels:
      app: curl
  template:
    metadata:
      labels:
        app: curl
    spec:
      containers:
      - name: curl
        image: curlimages/curl
        command: ["sleep", "3600"]
EOF
```

We can again verify the deployment of the test pod in the **pets** namespace using following command:

```bash
kubectl get pods -n pets | grep curl
```

Wait for the test pod to be in a **Running** state, and notice the **READY** state, which should have a status of **2/2**.

Run the following command to get the name of the test pod in the **pets** namespace.

```bash
CURL_PETS_POD_NAME="$(kubectl get pod -n pets -l app=curl -o jsonpath="{.items[0].metadata.name}")"
```

Run the following command to run a curl command from the test pod in the **pets** namespace to the **store-front** service.

```bash
kubectl exec -it ${CURL_PETS_POD_NAME} -n pets -- curl -IL store-front.pets.svc.cluster.local:80
```

You should see a response with a status of **HTTP/1.1 200 OK** indicating that the **store-front** service successfully responded to the client in the **pets** namespace using only mTLS communication.

---

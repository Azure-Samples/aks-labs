---
sidebar_position: 2
sidebar_label: Istio Service Mesh
title: Istio Service Mesh on AKS
---

Istio is an open-source service mesh that layers transparently onto existing distributed applications. Istio’s powerful features provide a uniform and more efficient way to secure, connect, and monitor services. Istio enables load balancing, service-to-service authentication, and monitoring – with few or no service code changes. Its powerful control plane brings vital features, including:

- Secure service-to-service communication in a cluster with TLS (Transport Layer Security) encryption, strong identity-based authentication, and authorization.
- Automatic load balancing for HTTP, gRPC, WebSocket, and TCP traffic.
- Fine-grained control of traffic behavior with rich routing rules, retries, failovers, and fault injection.
- A pluggable policy layer and configuration API supporting access controls, rate limits, and quotas.
- Automatic metrics, logs, and traces for all traffic within a cluster, including cluster ingress and egress.

The AKS Istio add-on simplifies Istio deployment and management, removing the need for manual installation and configuration.

## **Objectives**  

In this workshop, you will learn how to use the Istio service mesh with Azure Kubernetes Service (AKS). You will enable the Istio add-on in AKS, deploy services into the mesh, and configure mutual TLS (mTLS) to secure service-to-service communication. You will also expose an application to the internet using the Istio Ingress Gateway and use Kiali to observe traffic within the mesh.

:::info

Please be aware that the Istio addon for AKS does not provide the full functionality of the Istio upstream project. You can view the current limitations for this AKS Istio addon [here](https://learn.microsoft.com/azure/aks/istio-about#limitations) and what is currently [Allowed, supported, and blocked MeshConfig values](https://learn.microsoft.com/azure/aks/istio-meshconfig#allowed-supported-and-blocked-meshconfig-values)
:::

## Prerequisites  
Before starting this lab, make sure your environment is set up correctly. Follow the guide here:  

➡️ [Setting Up Lab Environment](https://azure-samples.github.io/aks-labs/docs/getting-started/setting-up-lab-environment)  

This lab covers:  
- Installing Azure CLI and Kubectl  
- Creating an AKS cluster  
- Configuring your local environment  

Once your cluster is ready and `kubectl` is configured, proceed to the next step.

## Install Istio on AKS  

The AKS Istio add-on simplifies service mesh deployment, removing the need for manual setup.  

Run the following command to enable Istio on your AKS cluster:  

```bash
az aks mesh enable \
  --resource-group <RG_NAME> \
  --name <AKS_NAME>
```

🔹 **Replace placeholders before running:**  
- `<RG_NAME>` → Your Azure **Resource Group**  
- `<AKS_NAME>` → Your AKS **cluster name**  

This enables Istio system components like **istiod** (control plane).  

:::note
**This step takes a few minutes.** You won’t see immediate output, but you can check the progress in the next step.
:::

Check if Istio components are running:  

```bash
kubectl get pods -n aks-istio-system
```

Expected output:

```
NAME                               READY   STATUS    RESTARTS   AGE
istiod-asm-1-23-564586fc99-ghbwt   1/1     Running   0          64s
istiod-asm-1-23-564586fc99-wk9q7   1/1     Running   0          49s
```

If Istio pods are in a **Running** state, the installation is complete. If they are **Pending** or **CrashLoopBackOff**, wait a few minutes and check again.

If pods stay in CrashLoopBackOff, there's likely a configuration or resource issue—check logs with `kubectl logs` and describe the pod with `kubectl describe pod <pod-name>` to troubleshoot.


## Deploy a Sample Application

We'll deploy a **pets** application with three services:  
- **store-front** (user-facing UI)  
- **order-service** (handles orders)  
- **product-service** (manages products)  

### Deploy the Application

:::info
If you have deployed the AKS Store Demo application from the Setting up the Lab Environment guide you can skip this step.
:::

First, create a namespace for the application:  

```bash
kubectl create namespace pets
```

Then, deploy the services:  

```bash
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/refs/heads/main/aks-store-quickstart.yaml -n pets
```

Check that the pods are running:  

```bash
kubectl get pods -n pets
```

At this point, the application is running **without Istio sidecars**.

## Enable Sidecar Injection

Service meshes traditionally work by deploying an additional container within the same pod as your application container. These additional containers are referred to as a sidecar or a sidecar proxy. These sidecar proxies receive policy and configuration from the service mesh control plane, and insert themselves in the communication path of your application to control the traffic to and from your application container.

The first step to onboarding your application into a service mesh, is to enable sidecar injection for your application pods. To control which applications are onboarded to the service mesh, we can target specific Kubernetes namespaces where applications are deployed.

:::info
For upgrade scenarios, it is possible to run multiple Istio add-on control planes with different versions. The following command enables sidecar injection for the Istio revision asm-1-23. If you are not sure which revision is installed on the cluster, you can run the following command `az aks show --resource-group ${RG_NAME} --name ${AKS_NAME} --query "serviceMeshProfile.istio.revisions"`
:::

The following command will enable the AKS Istio add-on sidecar injection for the `pets` namespace for the Istio revision **1.23**.

```bash
kubectl label namespace pets istio.io/rev=asm-1-23
```

At this point, we have simply just labeled the namespace, instructing the Istio control plane to enable sidecar injection on new deployments into the namespace. Since we have existing deployments in the namespace already, we will need to restart the deployments to trigger the sidecar injection.

Get a list of all the current pods running in the pets namespace.

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

The applications are now part of the Istio mesh and can use its features like traffic management, security, and observability.

## Secure Service Communication with mTLS  

Istio allows services to communicate securely using **mutual TLS (mTLS)**. This ensures that:  

- **Encryption**: All service-to-service traffic is encrypted.  
- **Authentication**: Services verify each other’s identity before communicating.  
- **Zero Trust Security**: Even if a service inside the cluster is compromised, it can’t talk to other services unless it’s part of the mesh.  

By default, Istio allows **both plaintext (unencrypted) and mTLS traffic**. We’ll enforce **strict mTLS**, so all communication inside the `pets` namespace is encrypted and authenticated.  

### What is PeerAuthentication?  

A **PeerAuthentication policy** in Istio controls how services accept traffic. It lets you:  

- Require **mTLS for all services** in a namespace.  
- Allow both plaintext and mTLS (permissive mode).  
- Disable mTLS if needed.  

We’ll apply a **PeerAuthentication policy** to require mTLS for all services in the `pets` namespace.  

### Test Communication Before Enforcing mTLS  

First, deploy a test pod **outside** the mesh, in the **default** namespace, to simulate an external client:  

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
        image: docker.io/curlimages/curl
        command: ["sleep", "3600"]
EOF
```

Once the pod is running, try sending a request to the **store-front** service:

Run the following command to get the name of the test pod.

```bash
CURL_POD_NAME="$(kubectl get pod -l app=curl -o jsonpath="{.items[0].metadata.name}")"
kubectl exec -it ${CURL_POD_NAME} -- curl -IL store-front.pets.svc.cluster.local:80
```

You should see a **HTTP/1.1 200 OK** response, meaning the service is **accepting unencrypted traffic**.

### Apply PeerAuthentication to Enforce mTLS  

Now, enforce **strict mTLS** for all services in the `pets` namespace:

```bash
kubectl apply -n pets -f - <<EOF
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: pets-mtls
  namespace: pets
spec:
  mtls:
    mode: STRICT
EOF
```

What this does:
✅ Forces all services in the `pets` namespace to **only** accept encrypted mTLS traffic.  
✅ Blocks **any** plaintext communication.  

### Test Communication Again

Try sending the same request from the **outside** test pod:

```bash
kubectl exec -it ${CURL_POD_NAME} -- curl -IL store-front.pets.svc.cluster.local:80
```

This time, the request **fails** because the `store-front` service now **rejects plaintext connections**.

To verify that **services inside the mesh can still communicate**, deploy a **test pod inside** the `pets` namespace:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: curl-inside
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

Once it’s running, get its name:

```bash
CURL_INSIDE_POD="$(kubectl get pod -n pets -l app=curl -o jsonpath="{.items[0].metadata.name}")"
```

Then, try the request again:

```bash
kubectl exec -it ${CURL_INSIDE_POD} -n pets -- curl -IL store-front.pets.svc.cluster.local:80
```

This **succeeds**, proving that **only Istio-managed services inside the mesh** can talk to each other.

So far, the `store-front` service is only accessible **inside the cluster**. To allow **external users** to access it (e.g., from a browser), we need an **Istio Ingress Gateway**.  

## Expose Services with Istio Ingress Gateway

### What is an Istio Ingress Gateway?
An **Ingress Gateway** is an Istio-managed entry point that:  
✅ Controls incoming traffic from the internet.  
✅ Can enforce security, rate limiting, and routing rules.  
✅ Works like a Kubernetes Ingress but provides more flexibility.

### Enabling Istio Ingress Gateway

With the usage of the AKS Istio add-on we can easily enable the Istio Ingress Gateway controller, removing the need for manual steps.

Run the following command to enable Istio Ingress Gateway on your cluster:

```bash
az aks mesh enable-ingress-gateway  \
  --resource-group <RG_NAME> \
  --name <AKS_NAME> \
  --ingress-gateway-type external
```

🔹 **Replace placeholders before running:**  
- `<RG_NAME>` → Your Azure **Resource Group**  
- `<AKS_NAME>` → Your AKS **cluster name**

This enabled **ingressgateway** (external traffic management).

:::note
**This step takes a few minutes.** You won’t see immediate output, but you can check the progress in the next step.
:::

Check if Istio components are running:  

```bash
kubectl get pods -n aks-istio-ingress
```

Expected output:

```
NAME                                                          READY   STATUS    RESTARTS   AGE
aks-istio-ingressgateway-external-asm-1-23-698f9ccc98-ktgqw   1/1     Running   0          2m41s
aks-istio-ingressgateway-external-asm-1-23-698f9ccc98-pkrww   1/1     Running   0          2m26s
```

If Istio pods are in a **Running** state, the installation is complete. If they are **Pending** or **CrashLoopBackOff**, wait a few minutes and check again.

### Create an Istio Gateway

We’ll define a **Gateway** resource that listens on **HTTP (port 80)** and forwards traffic to our `store-front` service.

Apply the following Gateway resource:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: pets-gateway
  namespace: pets
spec:
  selector:
    istio: aks-istio-ingressgateway-external
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
EOF
```

:::info
The selector used in the Gateway object points to istio: aks-istio-ingressgateway-external, which can be found as label on the service mapped to the external ingress that was enabled earlier.
:::

### Create a VirtualService to Route Traffic

A **Gateway** only defines how traffic enters the cluster. We also need a **VirtualService** to route traffic from the gateway to `store-front`.

Apply the VirtualService inline to route traffic to `store-front`:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: pets-route
  namespace: pets
spec:
  hosts:
  - "*"
  gateways:
  - pets-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: store-front
        port:
          number: 80
EOF
```

### Find the External IP

Check the **Istio Ingress Gateway** service to get the external IP:

```bash
kubectl get svc -n aks-istio-ingress
```

Expected output:

```
NAME                                TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)                                      AGE
aks-istio-ingressgateway-external   LoadBalancer   172.16.0.128   131.145.32.126   15021:32312/TCP,80:30483/TCP,443:32303/TCP   5m5s
```

The **EXTERNAL-IP** field is the public IP of your `aks-istio-ingressgateway-external`.  

### Test External Access

Copy the external IP and open it in a browser:

```
http://<EXTERNAL-IP>
```

or test with `curl`:

```bash
curl http://<EXTERNAL-IP>
```

You should see the **store-front service response**.

## Summary

🎉 Congratulations on completing this lab!  

You now have **hands-on experience** with **Istio on AKS**, learning how to secure and manage microservices at scale. Hopefully, you had fun, but unfortunately, all good things must come to an end. 🥲  

### What We Learned
In this lab, you:  
✅ Enabled the **Istio add-on** in AKS to simplify service mesh deployment  
✅ Deployed a **sample application** and onboarded it into the Istio mesh  
✅ Configured **automatic sidecar injection**  
✅ Enforced **strict mTLS** to secure service-to-service communication  
✅ Used **Kiali** to visualize traffic flows and security policies  
✅ Exposed services externally using an **Istio Ingress Gateway**  

## Next Steps

This lab introduced core **Istio on AKS** concepts, but there's more you can explore:  

🔹 **Traffic Management** → Implement **canary deployments**, **A/B testing**, or **fault injection**.  
🔹 **Advanced Security** → Apply **Istio AuthorizationPolicies** to restrict access based on user identity.  
🔹 **Performance Monitoring** → Integrate **Prometheus and Grafana** to track service performance and error rates.  
🔹 **Scaling & Upgrades** → Learn how to perform **rolling updates** for Istio and **auto-scale** workloads inside the mesh.  

If you want to dive deeper, check out:  
📖 [Istio Documentation](https://istio.io/latest/docs/)  
📖 [AKS Documentation](https://learn.microsoft.com/azure/aks/)  
📖 [Kubernetes Learning Path](https://learn.microsoft.com/en-us/training/paths/learn-kubernetes/)  

For more hands-on workshops, explore:  
🔗 [AKS Labs Catalog](https://azure-samples.github.io/aks-labs/catalog/)  
🔗 [Open Source Labs](https://aka.ms/oss-labs)  

## Cleanup (Optional)

If you no longer need the resources from this lab, you can delete your **AKS cluster**:  

```bash
az aks delete --resource-group <RG_NAME> --name <AKS_NAME> --yes --no-wait
```

Or remove just the **Istio components**:  

```bash
kubectl delete namespace aks-istio-system pets istio-system
```

## Stay Connected

If you have **questions, feedback, or just want to connect**, feel free to reach out!  

🐦 **Twitter/X:** [@Pixel_Robots](https://x.com/pixel_robots) \
🦋 **BlueSky** [@pixelrobots.co.uk](https://bsky.app/profile/pixelrobots.co.uk) \
💼 **LinkedIn:** [Richard Hooper](https://www.linkedin.com/in/%E2%98%81-richard-hooper/)  

Let me know what you think of this lab. I’d love to hear your feedback! 🚀 
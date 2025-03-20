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

This lab covers:

Enabling the Istio add-on in AKS.
Deploying services in the mesh.
Enforcing security with mTLS.
Observing Istio-managed traffic.

:::info

Please be aware that the Istio addon for AKS does not provide the full functionality of the Istio upstream project. You can view the current limitations for this AKS Istio addon [here](https://learn.microsoft.com/azure/aks/istio-about#limitations) and what is currently [Allowed, supported, and blocked MeshConfig values](https://learn.microsoft.com/azure/aks/istio-meshconfig#allowed-supported-and-blocked-meshconfig-values)
:::

## Prerequisites  
Before starting this lab, make sure your environment is set up correctly. Follow the guide here:  

➡️ [Setting Up Lab Environment](https://azure-samples.github.io/aks-labs/docs/getting-started/setting-up-lab-environment)  

This guide covers:  
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

This enables Istio system components like **istiod** (control plane) and **ingressgateway** (external traffic management).  

:::note
**This step takes a few minutes.** You won’t see immediate output, but you can check the progress in the next step.
:::

Check if Istio components are running:  

```bash
kubectl get pods -n aks-istio-system
```

Expected output:

```
NAME                                    READY   STATUS    RESTARTS   AGE
istiod-abc123                            1/1     Running   0          1m
istio-ingressgateway-xyz456              1/1     Running   0          1m
```

If Istio pods are in a **Running** state, the installation is complete. If they are **Pending** or **CrashLoopBackOff**, wait a few minutes and check again.

## Deploy a Sample Application

We'll deploy a **pets** application with three services:  
- **store-front** (user-facing UI)  
- **order-service** (handles orders)  
- **product-service** (manages products)  

### Deploy the Application
First, create a namespace for the application:  

```bash
kubectl create namespace pets
```

Then, deploy the services:  

```bash
kubectl apply -n pets -f https://raw.githubusercontent.com/your-repo/pets-app/main/deployment.yaml
```

Check that the pods are running:  

```bash
kubectl get pods -n pets
```

At this point, the application is running **without Istio sidecars**.

## Enable Sidecar Injection

To bring services into the Istio mesh, enable automatic **sidecar injection** for the `pets` namespace:  

```bash
kubectl label namespace pets istio-injection=enabled
```

Now, restart the deployments so that new pods get the sidecars injected:  

```bash
kubectl rollout restart deployment -n pets
```

Verify that the sidecars are injected by checking the pod status:  

```bash
kubectl get pods -n pets
```

Each pod should now show **2/2** containers—one for the application and one for the Istio proxy.  

This means the services are now part of the Istio mesh and can use its features like traffic management, security, and observability.

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

First, deploy a test pod **outside** the mesh to simulate an external client:  

```bash
kubectl run curl-outside --image=curlimages/curl -it -- sleep 3600
```

Once the pod is running, try sending a request to the **store-front** service:

```bash
kubectl exec -it curl-outside -- curl -IL store-front.pets.svc.cluster.local:80
```

You should see a **200 OK** response, meaning the service is **accepting unencrypted traffic**.

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
kubectl exec -it curl-outside -- curl -IL store-front.pets.svc.cluster.local:80
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

Now that Istio is securing traffic, we need a way to **visualize service-to-service communication, monitor traffic, and debug issues**.  

### What is Kiali?
Kiali is an Istio dashboard that helps you:  
- See a **service graph** of how workloads communicate.  
- Monitor traffic flows and request latency.  
- Check security policies (mTLS status, authorization rules).  
- Debug Istio configurations.  

## Enable Observability with Kiali

### Deploy Kiali

Istio provides **Kiali** as an optional component. Deploy it using the following command:  

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.18/samples/addons/kiali.yaml
```

Check if Kiali is running:  

```bash
kubectl get pods -n istio-system
```

Expected output (example):  

```
NAME                                   READY   STATUS    RESTARTS   AGE
kiali-abc123                           1/1     Running   0          1m
```

### Access the Kiali Dashboard

You can access Kiali using **port-forwarding (recommended)** or via a **LoadBalancer** if using **Azure Cloud Shell**.


import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

<Tabs>
  <TabItem value="local" label="Local Terminal (Recommended)" default>

If you're running commands from a **local machine**, use port-forwarding:

```bash
kubectl port-forward -n istio-system svc/kiali 20001:20001
```

Then, open your browser and go to:

➡️ **http://localhost:20001**

This method keeps Kiali internal to the cluster and is **more secure** than exposing it publicly.

  </TabItem>

  <TabItem value="cloud-shell" label="Azure Cloud Shell (Alternative - Not Best Practice)">

> ⚠️ **Warning:** This method exposes Kiali via a public LoadBalancer, which is **not recommended for production**. Instead, use an **Istio Ingress Gateway** for secure access.

Since **Azure Cloud Shell does not support `kubectl port-forward`**, patch the Kiali service to use a LoadBalancer:

```bash
kubectl patch svc kiali -n istio-system -p '{"spec": {"type": "LoadBalancer"}}'
```

Check the external IP:

```bash
kubectl get svc kiali -n istio-system
```

Example output:

```
NAME    TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)
kiali   LoadBalancer   10.0.200.100    52.123.45.67     20001:32456/TCP
```

Once the `EXTERNAL-IP` appears, open your browser and go to:

➡️ **http://EXTERNAL-IP:20001**

> ✅ **After testing, revert Kiali to a ClusterIP to remove public exposure:**

```bash
kubectl patch svc kiali -n istio-system -p '{"spec": {"type": "ClusterIP"}}'
```

  </TabItem>
</Tabs>


### View the Istio Service Graph

1. In Kiali, go to **Graph**.  
2. Select the `pets` namespace from the dropdown.  
3. You’ll see a **visual representation** of how `store-front`, `order-service`, and `product-service` communicate.  
4. Click on a service to view traffic, request success rates, and mTLS security status.  

### Generate Traffic to See Live Metrics  

Right now, your app isn't getting much traffic. To generate traffic, run:  

```bash
kubectl exec -it ${CURL_INSIDE_POD} -n pets -- watch -n 1 curl -s -o /dev/null -w "%{http_code}\n" store-front.pets.svc.cluster.local:80
```

Now, refresh the Kiali **Graph** tab and observe **real-time traffic flows**.  

So far, the `store-front` service is only accessible **inside the cluster**. To allow **external users** to access it (e.g., from a browser), we need an **Istio Ingress Gateway**.  


## Expose Services with Istio Ingress Gateway

### What is an Istio Ingress Gateway?
An **Ingress Gateway** is an Istio-managed entry point that:  
✅ Controls incoming traffic from the internet.  
✅ Can enforce security, rate limiting, and routing rules.  
✅ Works like a Kubernetes Ingress but provides more flexibility.  

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
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
EOF
```

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
kubectl get svc -n aks-istio-system
```

Expected output:

```
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
istio-ingressgateway   LoadBalancer   10.0.200.100    52.123.45.67    80:32567/TCP
```

The **EXTERNAL-IP** field is the public IP of your `istio-ingressgateway`.  

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
💼 **LinkedIn:** [Richard Hooper](https://www.linkedin.com/in/%E2%98%81-richard-hooper/)  

Let me know what you think of this lab. I’d love to hear your feedback! 🚀 
---
sidebar_position: 1
title: Advanced Container Networking Services
---

## Advanced Networking Concepts

When you created the AKS cluster you might have noticed that we used the Azure CNI network plugin in overlay mode with [Cilium](https://cilium.io/) for the network dataplane and security. This mode is the most advanced networking mode available in AKS and provides the most flexibility in how IP addresses are assigned to pods and how network policies are enforced.

In this section, you will explore advanced networking concepts such as network policies, FQDN filtering, and advanced container networking services.

### Advanced Container Networking Services

Advanced Container Networking Services (ACNS) is a suite of services built to significantly enhance the operational capabilities of your Azure Kubernetes Service (AKS) clusters.
Advanced Container Networking Services contains features split into two pillars:

- **Security**: For clusters using Azure CNI Powered by Cilium, network policies include fully qualified domain name (FQDN) filtering for tackling the complexities of maintaining configuration.
- **Observability**: The inaugural feature of the Advanced Container Networking Services suite bringing the power of Hubble’s control plane to both Cilium and non-Cilium Linux data planes. These features aim to provide visibility into networking and performance.

### Enforcing Network Policy

In this section, we’ll apply network policies to control traffic flow to and from the Pet Shop application. We will start with standard network policy that doesn't require ACNS, then we enforce more advanced FQDN policies.

#### Test Connectivity

Do the following test to make sure that all traffic is allowed by default

Run the following command to test a connection to an external website from the order-service pod.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service -- sh -c 'wget --spider www.bing.com'
```

You should see output similar to the following:

```text
Connecting to www.bing.com (13.107.21.237:80)
remote file exists
```

Now test the connection between the order-service and product-service pods which is allowed but not required by the architecture.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'nc -zv -w2 product-service 3002'
```

You should see output similar to the following:

```text
product-service (10.0.96.101:3002) open
```

In both tests, the connection was successful. This is because all traffic is allowed by default in Kubernetes.

#### Deploy Network Policy

Now, let's deploy some network policy to allow only the required ports in the pets namespace.

Run the following command to download the network policy manifest file.

```bash
curl -o acns-network-policy.yaml https://gist.githubusercontent.com/pauldotyu/64bdb2fdf99b24fc7922ff0101a6af5d/raw/141b085f1f4e57c214281400f576274676103801/acns-network-policy.yaml
```

Take a look at the network policy manifest file by running the following command.

```bash
cat acns-network-policy.yaml
```

Apply the network policy to the pets namespace.

```bash
kubectl apply -n pets -f acns-network-policy.yaml
```

#### Verify Policies

Review the created policies using the following command

```bash
kubectl get cnp -n pets
```

Ensure that only allowed connections succeed and others are blocked. For example, order-service should not be able to access www.bing.com or the product-service.

Run the following command to test the connection to www.bing.com from the order-service pod.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service -- sh -c 'wget --spider --timeout=1 --tries=1 www.bing.com'
```

You should see output similar to the following:

```text
wget: bad address 'www.bing.com'
command terminated with exit code 1
```

Run the following command to test the connection between the order-service and product-service pods.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'nc -zv -w2 product-service 3002'
```

You should see output similar to the following:

```text
nc: bad address 'product-service'
command terminated with exit code 1
```

We've just enforced network policies to control traffic flow to and from pods within the demo application. At the same time, we should be able to access the pet shop app UI and order product normally.

### Configuring FQDN Filtering

Using network policies, you can control traffic flow to and from your AKS cluster. This is traditionally been enforced based on IP addresses and ports. But what if you want to control traffic based on fully qualified domain names (FQDNs)? What if an application owner asks you to allow traffic to a specific domain like Microsoft Graph API?

This is where FQDN filtering comes in.

<div class="info" data-title="Note">

> FQDN filtering is only available for clusters using Azure CNI Powered by Cilium.

</div>

Let's explore how we can apply FQDN-based network policies to control outbound access to specific domains.

#### Test Connectivity

Let's start with testing the connection from the order-service to see if it can contact the Microsoft Graph API endpoint.

Run the following command to test the connection to the Microsoft Graph API from the order-service pod.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'wget --spider --timeout=1 --tries=1 https://graph.microsoft.com'
```

As you can see the traffic is denied. This is an expected behavior because we have implemented zero trust security policy and denying any unwanted traffic.

#### Create an FQDN Policy

To limit egress to certain domains, apply an FQDN policy. This policy permits access only to specified URLs, ensuring controlled outbound traffic.

<div class="info" data-title="Note">

> FQDN filtering requires ACNS to be enabled

</div>

Run the following command to download the FQDN policy manifest file.

```bash
curl -o acns-network-policy-fqdn.yaml https://gist.githubusercontent.com/pauldotyu/fd4cc689d9dcf8b0fd508620f3e6880d/raw/3e60c7e9bfb9ce5e7887ec7d81a6ca423002b14d/acns-network-policy-fqdn.yaml
```

Take a look at the FQDN policy manifest file by running the following command.

```bash
cat acns-network-policy-fqdn.yaml
```

```bash
kubectl apply -n pets -f acns-network-policy-fqdn.yaml
```

#### Verify FQDN Policy Enforcement

Now if we try to access Microsoft Graph API from order-service app, that should be allowed.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'wget --spider --timeout=1 --tries=1 https://graph.microsoft.com'
```

You should see output similar to the following:

```text
Connecting to graph.microsoft.com (20.190.152.88:443)
Connecting to developer.microsoft.com (23.45.149.11:443)
Connecting to developer.microsoft.com (23.45.149.11:443)
remote file exists
```

### Monitoring Advanced Network Metrics and Flows

Advanced Container Networking Services (ACNS) provides deep visibility into your cluster's network activity. This includes flow logs and deep visibility into your cluster's network activity. All communications to and from pods are logged, allowing you to investigate connectivity issues over time

Using Azure Managed Grafana, you can visualize real-time data and gain insights into network traffic patterns, performance, and policy effectiveness.

What if a customer reports a problem in accessing the pets shop? How can you troubleshoot the issue?

We'll work to simulate a problem and then use ACNS to troubleshoot the issue.

#### Introducing Chaos to Test container networking

Let's start by applying a new network policy to cause some chaos in the network. This policy will drop incoming traffic to the store-front service.

Run the following command to download the chaos policy manifest file.

```bash
curl -o acns-network-policy-chaos.yaml https://gist.githubusercontent.com/pauldotyu/9963e1301b8f3a460398b78a1e31ca84/raw/68f98f9a18dca5747248b434968e0074564a9c66/acns-network-policy-chaos.yaml
```

Run the following command to examine the chaos policy manifest file.

```bash
cat acns-network-policy-chaos.yaml
```

Run the following command to apply the chaos policy to the pets namespace.

```bash
kubectl apply -n pets -f acns-network-policy-chaos.yaml
```

#### Access Grafana Dashboard

When you enabled Advanced Container Networking Services (ACNS) on your AKS cluster, you also enabled metrics collection. These metrics provide insights into traffic volume, dropped packets, number of connections, etc. The metrics are stored in Prometheus format and, as such, you can view them in Grafana.

Using your browser, navigate to [Azure Portal](https://aka.ms/publicportal), search for **grafana** resource, then click on the **Azure Managed Grafana** link under the **Services** section. Locate the Azure Managed Grafana resource that was created earlier in the workshop and click on it, then click on the URL next to **Endpoint** to open the Grafana dashboard.

![Azure Managed Grafana overview](assets/acns-grafana-overview.png)

Part of ACNS we provide pre-defined networking dashboards. Review the available dashboards

![ACNS dashboards in Grafana](assets/acns-grafana-dashboards.png)

You can start with the **Kubernetes / Networking / Clusters** dashboard to get an over view of whats is happening in the cluster.

![ACNS networking clusters dashboard](assets/acns-network-clusters-dashboard.png)

Lets' change the view to the **Kubernetes / Networking / Drops**, select the **pets** namespace, and **store-front** workload

![ACNS networking drops dashboard](assets/acns-drops-incoming-traffic.png)

Now you can see increase in the dropped incoming traffic and the reason is "policy_denied" so now we now the reason that something was wrong with the network policy. let's dive dipper and understand why this is happening

[Optional] Familiarize yourself with the other dashboards for DNS, and pod flows

| ![DNS Dashboard](assets/acns-dns-dashboard.png) | ![Pod Flows Dashboard](assets/acns-pod-flows-dashboard.png) |
| ----------------------------------------------- | ----------------------------------------------------------- |

#### Observe network flows with hubble

ACNS integrates with Hubble to provide flow logs and deep visibility into your cluster's network activity. All communications to and from pods are logged allowing you to investigate connectivity issues over time.

But first we need to install Hubble CLI

Install Hubble CLI

```bash
# Set environment variables
export HUBBLE_VERSION="v0.11.0"
export HUBBLE_OS="$(uname | tr '[:upper:]' '[:lower:]')"
export HUBBLE_ARCH="$(uname -m)"

#Install Hubble CLI
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH="arm64"; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-${HUBBLE_OS}-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-${HUBBLE_OS}-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-${HUBBLE_OS}-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-${HUBBLE_OS}-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
```

Port forward Hubble Relay using the kubectl port-forward command.

```bash
kubectl port-forward -n kube-system svc/hubble-relay --address 127.0.0.1 4245:443
```

Move the port forward to the background by pressing **Ctrl + z** and then type **bg**.

Configure the client with hubble certificate

```bash
#!/usr/bin/env bash

set -euo pipefail
set -x

# Directory where certificates will be stored
CERT_DIR="$(pwd)/.certs"
mkdir -p "$CERT_DIR"

declare -A CERT_FILES=(
  ["tls.crt"]="tls-client-cert-file"
  ["tls.key"]="tls-client-key-file"
  ["ca.crt"]="tls-ca-cert-files"
)

for FILE in "${!CERT_FILES[@]}"; do
  KEY="${CERT_FILES[$FILE]}"
  JSONPATH="{.data['${FILE//./\\.}']}"

  # Retrieve the secret and decode it
  kubectl get secret hubble-relay-client-certs -n kube-system -o jsonpath="${JSONPATH}" | base64 -d > "$CERT_DIR/$FILE"

  # Set the appropriate hubble CLI config
  hubble config set "$KEY" "$CERT_DIR/$FILE"
done

hubble config set tls true
hubble config set tls-server-name instance.hubble-relay.cilium.io
```

Check Hubble pods are running using the `kubectl get pods` command.

```bash
kubectl get pods -o wide -n kube-system -l k8s-app=hubble-relay
```

Your output should look similar to the following example output:

```text
NAME                            READY   STATUS    RESTARTS   AGE    IP            NODE                                 NOMINATED NODE   READINESS GATES
hubble-relay-7ff97868ff-tvwcf   1/1     Running   0          101m   10.244.2.57   aks-systempool-10200747-vmss000000   <none>           <none>
```

Using hubble we will look for what is dropped.

```bash
hubble observe --verdict DROPPED
```

Here we can see traffic coming from world dropped in store-front

![Hubble CLI](assets/acns-hubble-cli.png)

So now we can tell that there is a problem with the frontend ingress traffic configuration, let's review the **allow-store-front-traffic** policy

```bash
kubectl describe -n pets cnp allow-store-front-traffic
```

Here we go, we see that the Ingress traffic is not allowed

![Ingress traffic not allowed](assets/acns-policy-output.png)

Now to solve the problem we will apply the original policy.

Run the following command to apply the original network policy to the pets namespace.

```bash
curl -o acns-network-policy-allow-store-front-traffic.yaml https://gist.githubusercontent.com/pauldotyu/013c496a3b26805ca213b5858d69e07c/raw/e7c7eb7d9bd2799a59eb66db9191c248435f2db4/acns-network-policy-allow-store-front-traffic.yaml
```

View the contents of the network policy manifest file.

```bash
cat acns-network-policy-allow-store-front-traffic.yaml
```

Apply the network policy to the pets namespace.

```bash
kubectl apply -n pets -f acns-network-policy-allow-store-front-traffic.yaml
```

You should now see the traffic flowing again and you are able to access the pets shop app UI.

### Visualize traffic with Hubble UI

#### Install Hubble UI

Run the following command to download the Hubble UI manifest file.

```bash
curl -o acns-hubble-ui.yaml https://gist.githubusercontent.com/pauldotyu/0daaba9833a714dc28ed0032158fb6fe/raw/801f9981a65009ed53e6596d06a9a8e73286ed21/acns-hubble-ui.yaml
```

Optionally, run the following command to take a look at the Hubble UI manifest file.

```bash
cat acns-hubble-ui.yaml
```

Apply the hubble-ui.yaml manifest to your cluster, using the following command

```bash
kubectl apply -f acns-hubble-ui.yaml
```

#### Forward Hubble Relay Traffic

Set up port forwarding for Hubble UI using the kubectl port-forward command.

```bash
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
```

#### Access Hubble UI

Access Hubble UI by entering http://localhost:12000/ into your web browser.

![Accessing the Hubble UI](assets/acns-hubble-ui.png)


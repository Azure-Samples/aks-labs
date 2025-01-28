---
sidebar_position: 2
title: Kubernetes the Easy Way with AKS Automatic
---

# Kubernetes the Easy Way with AKS Automatic

This workshop will guide you up to speed with working with Azure Kubernetes Service (AKS) Automatic. AKS Automatic is a new way to deploy and manage Kubernetes clusters on Azure. It is a fully managed Kubernetes service that simplifies the deployment, management, and operations of Kubernetes clusters. With AKS Automatic, you can deploy a Kubernetes cluster with just a few clicks in the Azure Portal. AKS Automatic is designed to be simple and easy to use, so you can focus on building and deploying your applications.

---

## Objectives

After completing this workshop, you will be able to:

- Deploy an application to an AKS Automatic cluster
- Troubleshoot application issues
- Integrate applications with Azure services
- Scale your cluster and applications
- Observe your cluster and applications

---

## Prerequisites

Before you begin, you will need an [Azure subscription](https://azure.microsoft.com/) with Owner permissions and a [GitHub account](https://github.com/signup).

In addition, you will need the following tools installed on your local machine:

- [Azure CLI](https://learn.microsoft.com/cli/azure/what-is-azure-cli?WT.mc_id=containers-105184-pauyu)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Git](https://git-scm.com/)
- [GitHub CLI](https://cli.github.com/)
- Bash shell (e.g. [Windows Terminal](https://www.microsoft.com/p/windows-terminal/9n0dx20hk701) with [WSL](https://docs.microsoft.com/windows/wsl/install-win10) or [Azure Cloud Shell](https://shell.azure.com))

To keep focus on AKS-specific features, this workshop will need some Azure resources to be pre-provisioned. You can use the following Azure CLI commands to create the resources:


Start by logging in to the Azure CLI.

```bash
az login
```

Register preview features.

```bash
az feature register --namespace Microsoft.ContainerService --name AutomaticSKUPreview
```

Register resource providers.

```bash
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ServiceLinker
```

Check the status of the feature registration.

```bash
az feature show --namespace Microsoft.ContainerService --name AutomaticSKUPreview --query properties.state
```

Once the feature is registered, run the following command to re-register the Microsoft.ContainerService provider.

```bash
az provider register --namespace Microsoft.ContainerService
```

Once the resource provider and preview features have been registered, create resource group.

```bash
az group create \
--name myresourcegroup \
--location eastus
```

Finally, run the following command to create resources for the workshop.

```bash
az deployment group create \
--resource-group myresourcegroup \
--template-uri https://raw.githubusercontent.com/Azure-Samples/aks-labs/refs/heads/main/docs/getting-started/assets/aks-automatic/azure-deploy.json \
--parameters nameSuffix=$(date +%s) userObjectId=$(az ad signed-in-user show --query id -o tsv) \
--query "properties.outputs"
```

This will create a new resource group and deploy the following resources:

- [Azure Container Registry](https://learn.microsoft.com/azure/container-registry/container-registry-intro) for storing container images
- [Azure CosmosDB database with a MongoDB API](https://learn.microsoft.com/azure/cosmos-db/mongodb/introduction) ([version 7.0](https://learn.microsoft.com/azure/cosmos-db/mongodb/feature-support-70)) and a database named **test**
- [Azure User-Assigned Managed Identity](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview) for CosmosDB access
- [Azure Monitor Workspace for Prometheus](https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-overview) metrics
- [Azure Log Analytics Workspace](https://learn.microsoft.com/azure/azure-monitor/logs/data-platform-logs) for [container insights](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-overview) and [application insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Azure Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/overview) for visualizing metrics

Once the resources are deployed, you can proceed with the workshop.

---

## Deploy your app to AKS Automatic

Let's jump right in and deploy an application to an AKS Automatic cluster. In this section, you will use AKS Automated Deployment to deploy a sample application hosted on GitHub to your AKS cluster.

With AKS, the [Automated Deployments](https://learn.microsoft.com/azure/aks/automated-deployments) feature allows you to create [GitHub Actions workflows](https://docs.github.com/actions) that allows you to start deploying your applications to your AKS cluster with minimal effort. All you need to do is point it at a GitHub repository with your application code. 

If you have Dockerfiles or Kubernetes manifests in your repository, that's great, you can simply point to them in the Automated Deployments setup. If you don't have Dockerfiles or Kubernetes manifests in your repository, don't sweat... Automated Deployments can create them for you!

### Fork and clone the sample repository

Open a bash shell and run the following command then follow the instructions printed in the terminal to complete the login process.

```bash
gh auth login
```

:::note

Here is an example of the login process with options selected.

```text
$ gh auth login
? Where do you use GitHub? GitHub.com
? What is your preferred protocol for Git operations on this host? HTTPS
? Authenticate Git with your GitHub credentials? Yes
? How would you like to authenticate GitHub CLI? Login with a web browser

! First copy your one-time code: 1234-ABCD
Press Enter to open https://github.com/login/device in your browser...
```

:::

After you've completed the login process, run the following command to fork the [contoso-air](https://github.com/pauldotyu/contoso-air) repository to your GitHub account.

```bash
gh repo fork pauldotyu/contoso-air --clone
```

Change into the `contoso-air` directory.

```bash
cd contoso-air
```

Set the default repository to your forked repository.

```bash
gh repo set-default
```

:::note

When prompted, select your fork of the repository and press **Enter**.

:::

You're now ready to deploy the sample application to your AKS cluster.

### Automated Deployments setup

In the Azure portal ([https://portal.azure.com](https://portal.azure.com)) type **Kubernetes services** in the search box at the top of the page and click the **Kubernetes services** option from the search results.

![Kubernetes services](./assets/aks-automatic/aks-search.png)

In the upper left portion of the screen, click the **+ Create** button to view all the available options for creating a new AKS cluster. Click on the **Deploy application (new)** option.

![Deploy application with Automated Deployment](./assets/aks-automatic/deploy-app.png)

In the **Basics** tab, click on the **Deploy your application** option, then select your Azure subscription and resource group.

![Automated Deployment basics](./assets/aks-automatic/deploy-app-basics.png)

In the **Repository details** section, type `contoso-air` as your **Workflow name**.

If you have not already authorized Azure to access your GitHub account, you will be prompted to do so. Click the **Authorize access** button to continue.

![GitHub authorization](./assets/aks-automatic/deploy-app-repo-auth.png)

Once your GitHub account is authorized, you will be able to select the repository you forked earlier. Click the **Select repository** drop down, then select the **contoso-air** repository you forked earlier and select the **main** branch.

![GitHub repo selection](./assets/aks-automatic/deploy-app-repo-selection.png)

Click **Next**.

In the **Application** tab, fill in the following in the **Image** section:

- **Container configuration**: Select **Auto-containerize (generate Dockerfile)**
- **Save files in repository**: Click the **Select** link to open the directory explorer, then navigate to the **Root/src** directory, select the checkbox next to the **web** folder, then click **Select**.

![Container image build context](./assets/aks-automatic/deploy-app-image-path.png)

Scroll down to the **Dockerfile configuration** section, fill in the following details:

- **Application environment**: Select **JavaScript - Node.js 22**
- **Application port**: Enter`3000`
- **Dockerfile build context**: Enter `./src/web`
- **Azure Container Registry**: Select your Azure Container Registry
- **Azure Container Registry image**: Click the **Create new** link then enter `contoso-air`

![Container image build configuration](./assets/aks-automatic/deploy-app-image.png)

Scroll down to the **Deployment configuration** section and fill in the following details:

- **Deployment options**: Select **Generate application deployment files**
- **Save files in repository**: Click the **Select** link to open the directory explorer, then select the checkbox next to the **Root** folder, then click **Select**.

![Kubernetes deployment manifest path](./assets/aks-automatic/deploy-app-manifest-path.png)

Click **Next**.

In the **Cluster configuration** section, make sure the **Create Automatic Kubernetes cluster** option is selected and set the **Kubernetes cluster name** to be `myakscluster`.

![AKS Automatic cluster creation](./assets/aks-automatic/deploy-app-cluster-new.png)

For **Namespace**, select **Create new** and enter `dev`.

You can leave the remaining fields as their default values.

![Kubernetes namespace](./assets/aks-automatic/deploy-app-cluster-logging.png)

:::note

You will see that the monitoring and logging options have been enabled by default and set to use the Azure resources that are available in your subscription. If you don't have these resources available, AKS Automatic will create them for you.

:::

Click **Next**.

In the **Review** tab, you will see a summary of the configuration you have selected and view a preview of the Dockerfile and Kubernetes deployment files that will be generated for you.

![Automated Deployment configuration review](./assets/aks-automatic/deploy-app-review.png)

When ready, click the **Deploy** button to start the deployment.

:::warning

This process can take up to 20 minutes to complete

:::

![Automated Deployment and AKS Cluster deployment](./assets/aks-automatic/deploy-app-deploy.png)

:::warning

There is a known issue of the default nodepool not having the proper labels and taints for Cilium to work properly. So we'll need to patch the default nodepool after the deployment is complete.

Run the following command to log into the AKS cluster:

```bash
az login
az aks get-credentials --resource-group myresourcegroup --name myakscluster
```

Run the following commands to see if the default nodepool has the proper labels and taints:

```bash
kubectl get nodepool default -o jsonpath='{.spec.template.metadata.labels}{"\n"}{.spec.template.spec.startupTaints}{"\n"}'
```

If you don't see any cilium related labels or startup taints, you will need to patch the nodepool. To patch the nodepool, run the following commands:

```bash
kubectl patch nodepool default --type='merge' -p '{
  "spec": {
    "template": {
      "metadata": {
        "labels": {
          "kubernetes.azure.com/ebpf-dataplane": "cilium"
        }
      },
      "spec": {
        "startupTaints": [
          {
            "key": "node.cilium.io/agent-not-ready",
            "effect": "NoExecute",
            "value": "true"
          }
        ]
      }
    }
  }
}'
```

:::

### Review the pull request

Back in the Azure portal, click on the **Approve pull request** button to view the pull request to be taken to the pull request page in your GitHub repository. 

![Automated Deployment success](./assets/aks-automatic/deploy-app-done.png)

In the pull request review, click on the **Files changed** tab to view the changes that were made by the Automated Deployments workflow. 

![GitHub pull request files changed](./assets/aks-automatic/github-pull-request-files.png)

:::warning

The Automated Deployments workflow generated a Kubernetes deployment manifest that will cause the contoso-air application to fail to start. This is because the startupProbe is not configured correctly. To fix this, scroll down to the **manifests/deployment.yaml**, click the 3-dots in the file name section and click **Edit file**. Scroll down to line 49 and update the startupProbe section to look like the following:

```yaml
startupProbe:
  tcpSocket:
    port: 3000
  periodSeconds: 5
  timeoutSeconds: 7
  failureThreshold: 3
  successThreshold: 1
  initialDelaySeconds: 5
```

Commit your changes directly to the **aks-devhub-**** branch when done.

:::

Navigate back to the **Conversation** tab and click on the **Merge pull request** button to merge the pull request, then click **Confirm merge**.

![GitHub merge pull request](./assets/aks-automatic/github-pull-request-merged.png)

With the pull request merged, the changes will be automatically deployed to your AKS cluster. You can view the deployment logs by clicking on the **Actions** tab in your GitHub repository.

![GitHub Actions tab](./assets/aks-automatic/github-actions.png)

In the **Actions** tab, you will see the Automated Deployments workflow running. Click on the workflow run to view the logs.

![GitHub Actions workflow run](./assets/aks-automatic/github-actions-workflow.png)

In the workflow run details page, you can view the logs of each step in the workflow by simply clicking on the step.

![GitHub Actions workflow logs](./assets/aks-automatic/github-actions-workflow-run.png)

After a few minutes, the workflow will complete and you will see two green check marks next to the **buildImage** and **deploy** steps. This means that the application has been successfully deployed to your AKS cluster.

![GitHub Actions workflow success](./assets/aks-automatic/github-action-done.png)

:::tip

If the deploy step fails, it is likely that Node Autoprovisioning (NAP) is still provisioning a new node for the cluster. Try clicking the "Re-run" button at the top of the page to re-run the deploy workflow step.

:::

### Test the deployed application

Back in the Azure portal, click the **Close** button to close the Automated Deployments setup. 

In the left-hand menu, click on **Services and ingresses** under the **Kubernetes resources** section. You should see a new service called `contoso-air` with a public IP address assigned to it. Click on the IP address to view the deployed application.

![Contoso Air service](./assets/aks-automatic/contoso-air-service-ip.png)

With AKS Automated Deployments, every time you push application code changes to your GitHub repository, the GitHub Action workflow will automatically build and deploy your application to your AKS cluster. This is a great way to automate the deployment process and ensure that your applications are always up-to-date!

Let's test the application functionality by clicking the **Login** link in the upper right corner of the page. 

![Contoso Air application](./assets/aks-automatic/contoso-air.png)

There is no authentication required, so you can simply type in whatever you like for the username and password and click the **Log in** button.

![Contoso Air login page](./assets/aks-automatic/contoso-air-login.png)

Click on the **Book** link in the top navigation bar and fill in the form with your trip details and click the **Find flights** button. 

![Contoso Air book flight](./assets/aks-automatic/contoso-air-book.png)

You will see some available flight options. Scroll to the bottom of the page and click **Next** to continue.

![Contoso Air flight options](./assets/aks-automatic/contoso-air-flights.png)

Did you notice that the application redirected you back to the login page? What happened? Let's find out...

### Troubleshoot the application

Head back over to the Azure portal and click on **Logs** under the **Monitoring** section of the AKS cluster left-hand menu. Here you can view the logs collected by the Azure Monitor agent running on the cluster nodes.

![Contoso Air container logs](./assets/aks-automatic/logs.png)

Close the **Queries hub** pop-up to get to the query editor, type the following query, then click the **Run** button to view container logs.

```kql
ContainerLogV2
| where LogLevel contains "error" and ContainerName == "contoso-air"
```

![Contoso Air error log query](./assets/aks-automatic/log-query.png)

Expand some of the logs to see the error messages that were generated by the application.

You should see an error message that says **Azure CosmosDB settings not found. Booking functionality not available.**.

![Contoso Air error logs query results](./assets/aks-automatic/log-query-result.png)

This error occurred because the application is trying to connect to an Azure CosmosDB database to store the booking information, but the connection settings are not configured. We can fix this by adding configuration to the application.

---

## Integrating apps with Azure services

Let's use the [AKS Service Connector](https://learn.microsoft.com/azure/service-connector/overview) to connect the application to Azure CosmosDB. Service Connector is a new feature that greatly simplifies the process of configuring [Workload Identity](https://learn.microsoft.com/azure/aks/workload-identity-overview?tabs=dotnet) for your applications running on AKS. [Workload Identity](https://learn.microsoft.com/entra/workload-id/workload-identities-overview) is a feature that allows you to assign an identity to a pod and use that identity to authenticate with Microsoft Entra ID to access Azure services.

:::tip

Workload Identity is the recommended way to authenticate with Azure services from your applications running on AKS. It is more secure than using service principals and does not require you to manage credentials in your application. To read more about the implementation of Workload Identity for Kubernetes, see [this doc](https://azure.github.io/azure-workload-identity/docs/).

:::

### Service Connector setup

In the left-hand menu, click on **Service Connector** under **Settings** then click on the **+ Create** button.

![AKS service connector](./assets/aks-automatic/service-connector.png)

In the **Basics** tab, enter the following details:

- **Kubernetes namespace**: Enter `dev`
- **Service type**: Select **Cosmos DB**
- **API type**: Select **MongoDB**
- **MongoDB database**: Select **test**

![AKS service connector basics](./assets/aks-automatic/service-connector-basics.png)

Click **Next: Authentication**.

In the **Authentication** tab, select the **Workload Identity** option and select the user-assigned managed identity with a name that starts with **mymongo**.

![AKS service connector authentication](./assets/aks-automatic/service-connector-auth.png)

Click **Next: Networking** then click **Next: Review + create** and finally click **Create**.

![AKS service connector review](./assets/aks-automatic/service-connector-review.png)

:::info

This process will take a few minutes as the Service Connector does some work behind the scenes to configure Workload Identity for the application. Some of the tasks include assigning the proper Azure role permissions to the [managed identity](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview) to access the CosmosDB, creating a [Federated Credential](https://learn.microsoft.com/entra/workload-id/workload-identity-federation) to establish trust between the Kubernetes cluster and the managed identity, creating a Kubernetes [ServiceAccount](https://kubernetes.io/docs/concepts/security/service-accounts/) with a link back to the managed identity, and finally creating a Kubernetes [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) with the CosmosDB endpoint information.

:::

### Configure the application for Workload Identity

Once the Service Connector for Azure CosmosDB has been created, you can configure the application to use the CosmosDB connection details.

In the Service Connector page, select the checkbox next to the CosmosDB connection and click the **Yaml snippet** button.

![AKS service connector yaml snippet](./assets/aks-automatic/service-connector-yaml-snippet.png)

In the **YAML snippet** window, select **Kubernetes Workload** for **Resource type**, then select **contoso-air** for **Kubernetes Workload**.

![AKS service connector yaml snippet for contoso-air](./assets/aks-automatic/service-connector-yaml-deploy.png)

You will see the YAML manifest for the contoso-air application with the highlighted edits required to connect to CosmosDB via Workload Identity.

![AKS service connector yaml snippet for contoso-air](./assets/aks-automatic/service-connector-yaml-deploy.png)

Scroll through the YAML manifest to view the changes highlighted in yellow, then click **Apply** to apply the changes to the application. This will redeploy the contoso-air application with the new connection details. 

![AKS service connector yaml snippet apply](./assets/aks-automatic/service-connector-yaml-apply.png)

Wait a minute or two for the new pod to be rolled out then navigate back to the application and attempt to book a flight. Now, you should be able to book a flight without any errors!

![Contoso Air flight booking success](./assets/aks-automatic/contoso-air-booked.png)

---

## Scaling your cluster and apps

Right now, the application is running a single pod. When the web app is under heavy load, it may not be able to handle the requests. To automatically scale your deployments, you should use [Kubernetes Event-driven Autoscaling (KEDA)](https://keda.sh/) which allows you to scale your application workloads based on utilization metrics, number of events in a queue, or based on a custom schedule using CRON expressions.

But simply using implementing KEDA is not enough. KEDA can try to deploy more pods, but if the cluster is out of resources, the pods will not be scheduled and remain in pending status. 

With AKS Automatic, [Node Autoprovisioning (NAP)](https://learn.microsoft.com/azure/aks/node-autoprovision?tabs=azure-cli) is enabled and is used over the traditional cluster autoscaler. With NAP, it can detect if there are pods pending scheduling and will automatically scale the node pool to meet the demands. We won't go into the details of working with NAP in this workshop, but you can read more about it in the [AKS documentation](https://learn.microsoft.com/azure/aks/node-autoprovision?tabs=azure-cli).

:::tip

NAP will not only automatically scale out additional nodes to meet demand, it will also find the most efficient VM configuration to host the demands of your workloads and scale nodes in when the demand is low to save costs.

:::

For the Kubernetes scheduler to efficiently schedule pods on nodes, it is best practice to include resource requests and limits in your pod configuration. The Automated Deployment setup added some default resource requests and limits to the pod configuration, but they may not be optimal. Knowing what to set the request and limit values to can be challenging. This is where the [Vertical Pod Autoscaler (VPA)](https://kubernetes.io/docs/tasks/run-application/vertical-pod-autoscaling/) can help. 

### Vertical Pod Autoscaler (VPA) setup

VPA is a Kubernetes resource that allows you to automatically adjust the CPU and memory requests and limits for your pods based on the actual resource utilization of the pods. This can help you optimize the resource utilization of your pods and reduce the risk of running out of resources.

AKS Automatic comes with the VPA controller pre-installed, so you can use the VPA resource immediately by simply deploying a VPA resource manifest to your cluster.

Navigate to the **Custom resource** section under **Kubernetes resources** in the AKS cluster left-hand menu. Scroll down to the bottom of the page and click on the **Load more** button to view all the available custom resources.

![Load more custom resources](./assets/aks-automatic/custom-resources-load-more.png)

Click on the **VerticalPodAutoscaler** resource to view the VPA resources in the cluster.

![VPA resources](./assets/aks-automatic/custom-resources-vpa.png)

Click on the **+ Create** button where you'll see a **Add with YAML** editor. 

![Create VPA](./assets/aks-automatic/custom-resources-vpa-create.png)

Not sure what to add here? No worries! You can lean on [Microsoft Copilot in Azure](https://learn.microsoft.com/azure/copilot/overview) to help generate the VPA manifest. 

Click in the text editor or press **Alt + I** to open the Copilot editor.

In the **Draft with Copilot** text box, type in the following prompt:

```text
Help me create a vertical pod autoscaler manifest for the contoso-air deployment in the dev namespace and set min and max cpu and memory to something typical for a nodejs app. Ensure the values for both requests and limits are set.
```

Press **Enter** to generate the VPA manifest.

When the VPA manifest is generated, click the **Accept all** button to accept the changes, then click **Add** to create the VPA resource.

![VPA manifest](./assets/aks-automatic/custom-resources-vpa-add.png)

:::warning

Microsoft Copilot in Azure may provide different results. If your results are different, make sure it is similar to the output listed in the screenshot above.

:::

:::tip

The VPA resource will only update the CPU and memory requests and limits for the pods in the deployment if the number of replicas is greater than 1. Also the pod will be restarted when the VPA resource updates the pod configuration so it is important to create [Pod Disruption Budgets (PDBs)](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets) to ensure that the pods are not restarted all at once.

:::

### KEDA scaler setup

AKS Automatic also comes with the KEDA controller pre-installed, so you can use the KEDA resource immediately by simply deploying a KEDA scaler to your cluster.

Navigate to **Application scaling** under **Settings** in the AKS cluster left-hand menu,  then click on the **+ Create** button.

![Application scaling](./assets/aks-automatic/keda.png)

In the **Basics** tab, enter the following details:

- **Name**: Enter `contoso-air-so`
- **Namespace**: Select **dev**
- **Target workload**: Select **contoso-air**
- **Minimum replicas**: Enter `3`
- **Maximum replicas**: Enter `10`
- **Trigger type**: Select **CPU**

![Application scaling basics](./assets/aks-automatic/keda-basics.png)

Leave the rest of the fields as their default values and click **Next**.

In the **Review + create** tab, click **Customize with YAML** to view the YAML manifest for the ScaledObject resource. You can see the YAML manifest the AKS portal generated for the ScaledObject resource. Here you can add additional configuration to the ScaledObject resource if needed.

Click **Save and create** to create the ScaledObject resource.

![Application scaling yaml](./assets/aks-automatic/keda-review.png)

Head over to the **Workloads** section in the left-hand menu under **Kubernetes resources**. In the **Filter by namespace** drop down list, select **dev**. You should see the **contoso-air** deployment is now running 3 replicas.

:::note

Now that the number of replicas has been increased, the VPA resource will be able to adjust the CPU and memory requests and limits for the pods in the deployment based on the actual resource utilization of the pods the next time it reconciles.

:::

This was a simple example of using using KEDA. The real power of KEDA comes from its ability to scale your application based on external metrics. There are many [scalers](https://keda.sh/docs/scalers/) available for KEDA that you can use to scale your application based on a variety of external metrics.

If you have time, try to run a simple load test to see the scaling in action. You can use the [hey](https://github.com/rakyll/hey) tool to generate some traffic to the application. 

Run the following command to generate some traffic to the application:

```bash
hey -z 30s http://<REPLACE_THIS_WITH_CONTOSO_AIR_SERVICE_IP>:3000
```

This will generate some traffic to the application for 30 seconds. You should see the number of replicas for the **contoso-air** deployment increase as the load increases.

:::tip

If you don't have hey installed on your system, you can install it by running the following commands:

```bash
curl -o hey https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
chmod +x hey
sudo mv hey /usr/local/bin
```

:::

---

## Observing your cluster and apps

Monitoring and observability are key components of running applications in production. With AKS Automatic, you get a lot of monitoring and observability features enabled out-of-the-box. If you recall from the beginning of the workshop, we created the AKS Automatic cluster and configured it to use the [Azure Log Analytics Workspace](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-overview), [Azure Monitor Managed Workspace](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli), and [Azure Managed Grafana](https://azure.microsoft.com/products/managed-grafana). Let's take a look at how you can use these features to monitor and observe your cluster and applications.

### Cluster and container insights

Navigate to the **Monitoring** section in the AKS cluster left-hand menu and click on **Insights**. Here you will see a high-level overview of how the cluster is performing.

![Cluster metrics](./assets/aks-automatic/insights.png)

The AKS Automatic cluster was also pre-configured with basic CPU utilization and memory utilization alerts. You can also create additional alerts based on the metrics collected by the Prometheus workspace.

Click on the **Recommended alerts (Preview)** button to view the recommended alerts for the cluster. Expand the **Prometheus community alert rules (Preview)** section to see the list of Prometheus alert rules that are available. You can enable any of these alerts by clicking on the toggle switch.

![Cluster alerts](./assets/aks-automatic/insights-recommended-alerts.png)

Click **Save** to enable the alerts.

### Workbooks and logs

With [Container Insights](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-overview) enabled, you can query the logs using Kusto Query Language (KQL). You can also create custom workbooks to visualize the data. One nice feature of Container Insights is having pre-configured workbooks that you can use to monitor your cluster and applications without having to write any queries.

In the **Monitoring** section of the AKS cluster left-hand menu, click on **Workbooks**. Here you will see a list of pre-configured workbooks that you can use to monitor your cluster. One workbook that is particularly useful is the **Cluster Optimization** workbook. This workbook can help you identify anomalies and detect application probe failures in addition to providing guidance on optimizing container resource requests and limits. Click on the **Cluster Optimization** workbook to view the details. Take some time to explore the other workbooks available in the list.

![Cluster optimization workbook](./assets/aks-automatic/insights-workbooks.png)

:::tip

The workbook visuals will include a query button that you can click to view the KQL query that powers the visual. This is a great way to learn how to write your own queries.

:::

If you click on the **Logs** section in the left-hand menu, you can view the logs collected by Container Insights. Here, you can write your own KQL queries or run pre-configured queries to logs from your cluster and applications. The Logs section should be configured to open **Queries hub** which displays a list of pre-configured queries that you can run. Click on a query and click **Run** to view the results.

### Visualizing metrics with Grafana

The Azure Portal provides a great way to view metrics and logs, but if you prefer to visualize the data using Grafana, or execute complex queries using PromQL, you can use the Azure Managed Grafana instance that was created with the AKS Automatic cluster.

In the AKS cluster's left-hand menu, click on **Insights** under the **Monitoring** section and click on the **View Grafana** button at the top of the page. This will open a window with the linked Azure Managed Grafana instance. Click on the **Browse dashboards** link. This will take you to the Azure Managed Grafana instance.

![Browse dashboards](./assets/aks-automatic/monitor-grafana.png)

Log into the Grafana instance then in the Grafana home page, click on the **Dashboards** link in the left-hand menu. Here you will see a list of pre-configured dashboards that you can use to visualize the metrics collected by the Prometheus workspace. 

In the **Dashboards** list, expand the **Azure Managed Prometheus** folder and explore the dashboards available. Each dashboard provides a different view of the metrics collected by the Prometheus workspace with controls to allow you to filter the data.

Click on a **Kubernetes / Compute Resources / Workload** dashboard.

![Grafana dashboards](./assets/aks-automatic/grafana-dashboards.png)

Filter the **namespace** to **dev** the **type** to **deployment**, and the **workload** to **contoso-air**. This will show you the metrics for the contoso-air deployment.

![Grafana compute workload dashboard](./assets/aks-automatic/grafana-compute-workload.png)

### Querying metrics with PromQL

If you prefer to write your own queries to visualize the data, you can use the **Explore** feature in Grafana. In the Grafana home page, click on the **Explore** link in the left-hand menu, and select the **Managed_Prometheus_defaultazuremonitorworkspace** data source.

The query editor supports a graphical query builder and a text-based query editor. The graphical query builder is a great way to get started with PromQL. You can select the metric you want to query, the aggregation function, and any filters you want to apply.

![Grafana explore with PromQL](./assets/aks-automatic/grafana-promql.png)

There is a lot you can do with Grafana and PromQL, so take some time to explore the features and visualize the metrics collected by the Prometheus workspace.

---

## Summary

In this workshop, you learned how to create an AKS Automatic cluster and deploy an application to the cluster using Automated Deployments. From there, you learned how to troubleshoot application issues using the Azure portal and how to integrate applications with Azure services using the AKS Service Connector. You also learned how to configure your applications for resource specific scaling using the Vertical Pod Autoscaler (VPA) and scaling your applications KEDA. Hopefully, you now have a better understanding of how easy it can be to build and deploy applications on AKS Automatic.

To learn more about AKS Automatic, visit the [AKS documentation](https://learn.microsoft.com/azure/aks/intro-aks-automatic).

In addition to this workshop, you can also explore the following resources:

- [Azure Kubernetes Service (AKS) documentation](https://learn.microsoft.com/azure/aks)
- [Kubernetes: Getting started](https://azure.microsoft.com/solutions/kubernetes-on-azure/get-started/)
- [Learning Path: Introduction to Kubernetes on Azure](https://learn.microsoft.com/training/paths/intro-to-kubernetes-on-azure/)
- [Learning Path: Deploy containers by using Azure Kubernetes Service (AKS)](https://learn.microsoft.com/training/paths/deploy-manage-containers-azure-kubernetes-service/)

If you have any feedback or suggestions for this workshop, please feel free to open an issue or pull request in the [GitHub repository](https://github.com/Azure-Samples/aks-labs)

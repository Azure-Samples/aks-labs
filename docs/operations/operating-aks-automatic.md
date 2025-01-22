---
# published: true # Optional. Set to true to publish the workshop (default: false)
# type: workshop # Required.
title: Streamline operations and developer onboarding with AKS Automatic # Required. Full title of the workshop
# short_title: Operating AKS Automatic # Optional. Short title displayed in the header
description: Are you looking for ways to automate many administrative tasks in Kubernetes and make it easier for development teams to deploy their apps while maintaining security and compliance? Azure Kubernetes Service (AKS) Automatic is a new mode of operation for AKS that simplifies cluster management, reduces manual tasks, and builds in enterprise-grade best practices and policy enforcement. This session is perfect for platform operators and DevOps engineers looking to get started with AKS Automatic. # Required.
# level: beginner # Required. Can be 'beginner', 'intermediate' or 'advanced'
# authors: # Required. You can add as many authors as needed
#   - "Paul Yu"
# contacts: # Required. Must match the number of authors
#   - "@pauldotyu"
# duration_minutes: 75 # Required. Estimated duration in minutes
# tags: kubernetes, azure, aks # Required. Tags for filtering and searching
# wt_id: WT.mc_id=containers-153036-pauyu
---

## Overview

AKS Automatic is a new mode of operation for Azure Kubernetes Service (AKS) that simplifies cluster management, reduces manual tasks, and builds in enterprise-grade best practices and policy enforcement. This lab is meant to be a hands-on experience for Azure administrators and DevOps engineers looking to get started with AKS Automatic. You will learn how to automate many administrative tasks in Kubernetes and make it easier for development teams to deploy their apps while maintaining security and compliance.

Many of the features you will be working with in this workshop are in preview and may not be recommended for production workloads. However, the AKS engineering team is working hard to bring these features to general availability and will be great learning opportunities for you to understand options to support developers and streamline operations. This is not platform engineering, but it is a step in the right direction to automate many of the tasks that platform engineers do today. If you would like to learn more about platform engineering with AKS, please check out this [repo](https://github.com/azure-samples/aks-platform-engineering).

### Objectives

By the end of this lab you will be able to:

- Manage user access to the AKS cluster
- Understand AKS Deployment Safeguards and how to enforce custom policies
- Sync configurations to the cluster with Azure App Configuration Provider for Kubernetes
- Leverage AKS Service Connector for passwordless integration with Azure services
- Scale workloads across nodes with AKS Node Autoprovision
- Understand workload scheduling best practices
- Troubleshoot workload failures with monitoring tools and Microsoft Copilot for Azure

### Prerequisites

The lab environment has been pre-configured for you with the following Azure resources in the resource group named **myresourcegroup**:

- [AKS Automatic](https://learn.microsoft.com/azure/aks/intro-aks-automatic) cluster with monitoring enabled
- [Azure Container Registry](https://learn.microsoft.com/azure/container-registry/container-registry-intro)
- [Azure Log Analytics Workspace](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview)
- [Azure Managed Prometheus](https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-overview)
- [Azure Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/overview)

> [!NOTE]
> The Bicep template used to deploy the lab environment can be found [here](https://raw.githubusercontent.com/azure-samples/aks-labs/refs/heads/ignite/workshops/operating-aks-automatic/assets/setup/bicep/aks.bicep). Just note that if you deploy this template, you will need to assign yourself the "Azure Kubernetes Service RBAC Cluster Admin" role to the AKS cluster and the "Grafana Admin" role to the Azure Managed Grafana resources.

You will also need the following tools:

- [Visual Studio Code](https://code.visualstudio.com/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [kubelogin](https://learn.microsoft.com/azure/aks/kubelogin-authentication)
- [Helm](https://helm.sh/docs/intro/install/)

> [!ALERT]
> All command-line instructions in this lab should be executed in a Bash shell. If you are using Windows, you can use the Windows Subsystem for Linux (WSL) or Azure Cloud Shell.

Before you get started, open a Bash shell and log in to your Azure subscription with the following command:

```bash
az login --use-device-code
```

You will be prompted to open a browser and log in with your Azure credentials. Copy the code that is displayed and paste it in the browser to authenticate.

You will also need to install the **aks-preview** and **k8s-extension** extensions to leverage preview features in AKS and install AKS extensions. Run the following commands to install the extensions.

```bash
az extension add --name aks-preview
az extension add --name k8s-extension
```

Finally set the default location for resources that you will create in this lab using Azure CLI.

```bash
az configure --defaults location=$(az group show -n myresourcegroup --query location -o tsv)
```

You are now ready to get started with the lab!

===

## Security and governance

Being able to manage user access to the AKS cluster and enforce policies is critical to maintaining a secure and compliant environment. In this section, you will learn how to grant permissions to the AKS cluster, enforce policies with AKS Deployment Safeguards, and enforce custom policies with Azure Policy.

### Granting permissions to the AKS cluster

With [Azure RBAC for Kubernetes authorization](https://learn.microsoft.com/azure/aks/manage-azure-rbac?tabs=azure-cli) enabled on the AKS Automatic cluster, granting users access to the cluster is as simple as assigning roles to users, groups, and/or service principals. Users will run the normal **az aks get-credentials** command to download the [kubeconfig file](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/), but when users attempt to execute commands against the Kubernetes API Server, they will be instructed to log in with their Microsoft Entra ID credentials and their assigned roles will determine what they can do within the cluster.

To grant permissions to the AKS cluster, you will need to assign an Azure role to a user. The following built-in roles are available for user assignment.

- [Azure Kubernetes Service RBAC Admin](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-admin)
- [Azure Kubernetes Service RBAC Cluster Admin](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-cluster-admin)
- [Azure Kubernetes Service RBAC Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-reader)
- [Azure Kubernetes Service RBAC Writer](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-rbac-writer)

In your shell, run the following command to get the AKS cluster credentials.

```bash
az aks get-credentials \
--resource-group myresourcegroup \
--name myakscluster
```

A Kubernetes [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) is often used to isolate resources in a cluster and is common practice to create namespaces for different teams or environments. Run the following command to create a namespace for the dev team to use.

```bash
kubectl create namespace dev
```

Since this is the first time you are running a [kubectl](https://kubernetes.io/docs/reference/kubectl/) command, you will be prompted to log in against Microsoft Entra ID.

Follow the same login process you went through to login into your Azure subscription. After you've successfully logged in, the command to create the namespace should be successful.

> [!HELP]
> If you run into an error when trying to log in, you may need to install the [kubelogin](https://github.com/Azure/kubelogin) plugin which is used to authenticate with Microsoft Entra ID. It can be easily installed with the following command: **az aks install-cli**.

Run the following command to get the AKS cluster's resource ID.

```bash
AKS_ID=$(az aks show \
--resource-group myresourcegroup \
--name myakscluster \
--query id \
--output tsv)
```

Run the following command to get a developer's user principal ID.

```bash
DEV_USER_PRINCIPAL_ID=$(az ad user show \
--id <dev_user_principal_name> \
--query id \
--output tsv)
```

> [!NOTE]
> Be sure to replace **dev_user_principal_name** with the actual user principal name of the developer.

Run the following command to assign the **Azure Kubernetes Service RBAC Writer** role to the developer and have the permissions scoped only to the **dev** namespace. This ensures that the developer can only access the resources within the namespace and not the entire cluster.

```bash
az role assignment create \
--role "Azure Kubernetes Service RBAC Writer" \
--assignee $DEV_USER_PRINCIPAL_ID \
--scope $AKS_ID/namespaces/dev
```

When you logged in to access the Kubernetes API via the kubectl command, you were prompted to log in with your Microsoft Entra ID. The kubelogin plugin stores the OIDC token in the **~/.kube/cache/kubelogin** directory. In order to quickly test the permissions of a different user, we can simply move the JSON file to a different directory.

Run the following command to temporarily move the cached credentials to its parent directory.

```bash
mv ~/.kube/cache/kubelogin/*.json ~/.kube/cache/
```

Now, run the following command to get the dev namespace.

```bash
kubectl get namespace dev
```

Since there is no cached token in the kubelogin directory, this will trigger a new authentication prompt. Proceed to log in with the developer's user account. So when you log in, be sure to click the **Use another account** button and enter a developer's user credentials.

After logging in, head back to your terminal. You should see details of the **dev** namespace. This means that the dev user has the necessary permissions to access the **dev** namespace.

Run the following command to check to see if the dev user can create a pod in the **dev** namespace.

```bash
kubectl auth can-i create pods --namespace dev
```

You should see the output **yes**. This means the dev user has the necessary permissions to create pods in the **dev** namespace.

Let's put this to the test and deploy a sample application in the assigned namespace using Helm.

Run the following command to add the Helm repository for the AKS Store Demo application.

```bash
helm repo add aks-store-demo https://azure-samples.github.io/aks-store-demo
```

Run the following command to install the [AKS Store Demo](https://github.com/azure-samples/aks-store-demo) application in the **dev** namespace.

```bash
helm install demo aks-store-demo/aks-store-demo-chart \
--namespace dev \
--set aiService.create=true
```

The helm install command should show a status of "deployed". This means that the application has successfully deployed in the **dev** namespace. It will take a few minutes to deploy, so let's move on.

Finally, check to see if the developer can create a pod outside of the dev namespace. Run the following command to test against the **default** namespace.

```bash
kubectl auth can-i create pods --namespace default
```

You should see the output **no - User does not have access to the resource in Azure. Update role assignment to allow access**.

This is exactly what we want to see. If you need to grant the user access to another namespace, you can simply assign the role to the user with the appropriate scope. Or if you need to grand a user access to the entire cluster, you can assign the role to the user with the scope of the AKS cluster and omit the namespace altogether.

Great job! You now know how to manage user access to the AKS cluster and how to scope permissions to specific namespaces.

> [!ALERT]
> After testing the permissions, delete the developer user's cached credentials, then move the admin user's cached credentials back to the **~/.kube/cache/kubelogin** directory by running the following commands.

```bash
rm ~/.kube/cache/kubelogin/*.json
mv ~/.kube/cache/*.json ~/.kube/cache/kubelogin/
```

### Deployment Safeguards

Before you unleash developers to deploy applications in the AKS cluster, you likely want to ensure that they are following best practices. [Deployment Safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards) is a feature that helps enforce best practices and policies for your AKS clusters. It is implemented as an AKS add-on using [Azure Policy](https://learn.microsoft.com/azure/governance/policy/overview) and enabled by default on AKS Automatic clusters. Deployment Safeguards is basically a group of policies known as an [initiative](https://learn.microsoft.com/azure/governance/policy/concepts/initiative-definition-structure) which is assigned to your cluster to ensure resources running within it are secure, compliant, and follows best practices. The compliance state of the cluster resources are reported back to Azure Policy and can be viewed in the Azure Portal.

The group of policies that are included with Deployment Safeguards are documented [here](https://learn.microsoft.com/azure/aks/deployment-safeguards#deployment-safeguards-policies). Read carefully through each policy description, the targeted resource, and the mutation that can be applied when the assignment is set to **Enforcement** mode. AKS Automatic defaults to **Warning** mode which simply displays warnings in the terminal as a gentle reminder to implement best practices. You may have seen Deployment Safeguards at work when you deployed the demo application using Helm. When Deployment Safeguards is in Enforcement mode, polices will be strongly enforced by either mutating deployments to comply with the policies or denying deployments that violate policy. Therefore, it is important to understand the impact of each policy before enabling Enforcement mode.

Run the following command to deploy a pod without any best practices in place.

```bash
kubectl run mynginx --image=nginx:latest
```

You should see the following warning messages in the output.

```text
Warning: [azurepolicy-k8sazurev2containerenforceprob-e00c7e64611b1137ed2b] Container <nginx> in your Pod <nginx> has no <livenessProbe>. Required probes: ["readinessProbe", "livenessProbe"]
Warning: [azurepolicy-k8sazurev2containerenforceprob-e00c7e64611b1137ed2b] Container <nginx> in your Pod <nginx> has no <readinessProbe>. Required probes: ["readinessProbe", "livenessProbe"]
Warning: [azurepolicy-k8sazurev3containerlimits-4e7bbc2617e5447639a7] container <nginx> has no resource limits
Warning: [azurepolicy-k8sazurev1containerrestrictedi-88f886218244b623dd93] nginx in default does not have imagePullSecrets. Unauthenticated image pulls are not recommended.
pod/nginx created
```

These warnings are here to help remind you of the best practices that should be followed when deploying pods in the AKS cluster. There are warnings about not having a [livenessProbe](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-a-liveness-http-request), [readinessProbe](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-readiness-probes), [resource limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits), and [imagePullSecrets](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-pod-that-uses-your-secret).

So let's try this again with some best practices in place. Run the following command to delete the pod that was just created.

```bash
kubectl delete pod mynginx --wait=false
```

Run the following command to redeploy the pod with some best practices in place.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: mynginx
  name: mynginx
spec:
  containers:
  - image: nginx:latest
    name: mynginx
    resources:
      limits:
        cpu: 5m
        memory: 4Mi
      requests:
        cpu: 3m
        memory: 2Mi
    livenessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 3
    readinessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 3
EOF
```

This pod manifest is a bit more complex this time but it includes the following best practices that includes resource limits and requests as well as liveness and readiness probes.

> [!HINT]
> You should now see that we've satisfied all but one best practice, which we'll address later.

You can also view the compliance state of the cluster resources in the Azure Portal.

Head over to the Azure portal. In the search bar, type `policy` and click on **Policy** under **Services**.

In the **Overview** section, you will see the **AKS Deployment Safeguards Policy Assignment** in the middle of the page.

Click on the policy assignment to view the compliance state of the cluster resources. You should see some of the policy warnings that were displayed in the terminal output when you deployed the pod without best practices in place.

Nice! Now you know where to expect to see warnings both in the terminal and in the Azure and how to address some of these warnings by following best practices.

### Custom policy enforcement

As mentioned in the previous section, the [Azure Policy add-on for AKS](https://learn.microsoft.com/azure/aks/use-azure-policy) has been enabled when AKS Automatic is provisioned. This means you have everything you need leverage additional Azure Policy definitions (built-in or custom) to enforce organizational standards. When the Azure Policy for AKS feature is enabled, [Open Policy Agent (OPA) Gatekeeper](https://kubernetes.io/blog/2019/08/06/opa-gatekeeper-policy-and-governance-for-kubernetes/) is deployed in the AKS cluster. [Gatekeeper](https://open-policy-agent.github.io/gatekeeper) is a policy engine for Kubernetes that allows you to enforce policies written using [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/), a high-level declarative language. As Azure policies are assigned to the AKS cluster, they are translated to Gatekeeper [ConstraintTemplates](https://open-policy-agent.github.io/gatekeeper/website/docs/constrainttemplates/) and enforced in the cluster.

The Gatekeeper pods are running in the **gatekeeper-system** namespace. Run the following command to view the pods.

```bash
kubectl get pods -n gatekeeper-system
```

You can also view the ConstraintTemplates that are available in the cluster. Run the following command to view the ConstraintTemplates which have been deployed via the Azure Policy add-on for AKS.

```bash
kubectl get constrainttemplates
```

Although Gatekeepr is running in the cluster, it is worth noting that this Gatekeeper cannot be used outside of Azure Policy. That is, if you want to implement a well-known or commonly used ConstraintTemplates, you'll need to translate it to an Azure Policy definition and assign it to the AKS cluster. From there **azure-policy-\*** pods running in the **kube-system** namespace listens for Azure Policy assignments, translates them to ConstraintTemplates, deploys the custom Constraints (cluster policy), and reports the cluster policy results back up to Azure Policy.

Let's illustrate this by attempting to deploy a commonly used ConstraintTemplate that limits container images to only those from approved container registries. Run the following command to attempt to deploy the ConstraintTemplate.

```bash
kubectl apply -f https://raw.githubusercontent.com/azure-samples/aks-labs/refs/heads/ignite/workshops/operating-aks-automatic/assets/files/constrainttemplate.yaml
```

In the output you should see **This cluster is governed by Azure Policy. Policies must be created through Azure.**

So we need to translate this ConstraintTemplate to an Azure Policy definition and if you are unsure about how to translate ConstraintTemplates to Azure Policy JSON, the [Azure Policy extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=AzurePolicy.azurepolicyextension) is available to help.

#### Create a custom policy definition from a ConstraintTemplate

Using the Azure Policy extension for Visual Studio Code, you can easily create a custom policy definition from a ConstraintTemplate.

- Open VS Code and make sure the Azure Policy extension is installed. If not, you can install it from the [VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=AzurePolicy.azurepolicyextension)
- To activate the extension, press **Ctrl+Shift+P** on your keyboard to open the command palette and type **Azure: Sign in** then use the web browser to authenticate with your admin user account

> [!HINT]
> If you see multiple sign-in options, choose the one that has **azure-account.login** next to it.

- Press **Ctrl+Shift+P** again and type **Azure: Select Subscriptions** then select the subscription that contains the AKS cluster

> [!HINT]
> If you see multiple subscriptions, choose the one that has **azure-account.selectSubscriptions** next to it.

- In VS Code sidebar, click the **Azure Policy** icon and you should see the subscription resources and policies panes being loaded
- Open the VS Code terminal and run the following command download the sample ConstraintTemplate file to your local machine

```bash
curl -o constrainttemplate.yaml https://raw.githubusercontent.com/azure-samples/aks-labs/refs/heads/ignite/workshops/operating-aks-automatic/assets/files/constrainttemplate.yaml
```

- Open the constrainttemplate.yaml file in VS Code and take a look at the contents

```bash
code constrainttemplate.yaml
```

> [!KNOWLEDGE]
> The constraint template includes Rego code on line 17 that enforces that all containers in the AKS cluster are sourced from approved container registries. The approved container registries can are defined in the **registry** parameter and this is where you can specify the container registry URL when implementing the ConstraintTemplate.

- To convert this template to Azure Policy JSON, press **Ctrl+Shift+P** then type **Azure Policy for Kubernetes: Create Policy Definition from a Constraint Template**
- Select the **Base64Encoded** option

> [!HELP]
> The extension activation process can take a few minutes to complete. If you cannot get the extension to generate JSON from the ConstraintTemplate, that's okay, skip to the [Deploy a custom policy definition](#deploy-a-custom-policy-definition) section below where you will use a sample Azure Policy JSON file.

- This will generate a new Azure Policy definition in the JSON format and encode the ConstraintTemplate in Base64 format

> [!HINT]
> The template info can also refer to a URL where the ConstraintTemplate is hosted. This is useful when you want to reference a ConstraintTemplate that is hosted in a public repository.

- Fill in details where you see the text **/_ EDIT HERE _/**
  - For **displayName** field use the value `Approved registries only`
  - For **description** field use the value `This policy requires that all containers in an AKS cluster are sourced from approved container registries.`
  - For **apiGroups** field use the value `[""]` to target all API groups
  - For the **kind** field use the value `["Pod"]` to target pods

#### Deploy a custom policy definition

With the custom policy rule written, you can now deploy it to Azure.

- Open a terminal and run the following command to download the sample Azure Policy JSON file to your local machine

```bash
curl -o constrainttemplate-as-policy.json https://raw.githubusercontent.com/Azure-Samples/aks-labs/refs/heads/ignite/workshops/operating-aks-automatic/assets/files/constrainttemplate-as-policy.json
```

- Open **constrainttemplate-as-policy.json** file and copy the JSON to the clipboard

```bash
code constrainttemplate-as-policy.json
```

- Navigate back to the [Azure Policy blade](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Overview) in the Azure Portal
- Click on **Definitions** under the **Authoring** section
- Click on **+ Policy definition** then enter the following details:
  - **Definition location**: Click the button next to the textbox, then select your subscription in the dropdown and click the **Select** button at the bottom
  - **Name**: `[AKS] Approved registries only`
  - **Description**: `This policy requires that all containers in an AKS cluster are sourced from approved container registries.`
  - **Category**: Click the **Use existing** radio button then select **Kubernetes** from the dropdown
  - **Policy rule**: Clear the existing content and paste the JSON you copied from the **constrainttemplate-as-policy.json** file
- Click **Save** at the bottom of the page

#### Assign a custom policy to the AKS cluster

With the custom policy definition created, you can now assign it to the AKS cluster.

- Click the **Assign policy** button
- In the **Basics** tab, enter the following details:
  - **Scope**: Click the button next to the textbox, select the **myresourcegroup** which contains the AKS cluster and click **Select** at the bottom
- Click **Next**
- In the **Parameters** tab, enter the following details:
  - Uncheck the **Only show parameters that need input or review** checkbox
  - **Effect**: Select **deny** from the dropdown
  - **Namespace exclusions**: Replace the existing content with `["kube-system","gatekeeper-system","azure-arc", "kube-node-lease","kube-public","app-routing-system","azappconfig-system","sc-system","aks-command"]`
  - **Image registry**: Enter your container registry URL as `<your_acr_name>.azurecr.io/`
- Click **Review + create** to review the policy assignment
- Click **Create** to assign the policy definition to the AKS cluster

> [!ALERT]
> This policy assignment uses **Namespace exclusions** to exclude system namespaces from the policy enforcement. This is important because you may deny the deployment of certain pods if the namespaces are not "whitelisted" in the policy assignment. The alternative here is to only apply the policy to a specific namespace by using the **Namespace inclusions** parameter instead and specifying the namespace you want to enforce the policy on.

Awesome! You have successfully enforced custom policies in the AKS cluster. Once the policy assignment has taken effect, you can try deploying a pod with an image from an unapproved container registry to see the policy in action. However, this policy assignment can take up to 15 minutes to take effect, so let's move on to the next section.

For more information on how to create a policy definition from a ConstraintTemplate or MutationTemplate, refer to the following documentation links:

- [Create policy definition from a constraint template or mutation template](https://learn.microsoft.com/azure/governance/policy/how-to/extension-for-vscode#create-policy-definition-from-a-constraint-template-or-mutation-template)
- [Understand Azure Policy for Kubernetes clusters](https://learn.microsoft.com/azure/governance/policy/concepts/policy-for-kubernetes)
- [OPA Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library/)

===

## Secrets and config management

Azure service integration with developers requires access to configurations for their cluster workloads and leveraging password-less Microsoft Entra ID authentication wherever possible. This section guides you through centralizing configuration storage, syncing configs as Kubernetes ConfigMaps, and setting up connectors for workload integration with Azure services.

[Azure Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview) is a cloud service for securely storing and accessing secrets. A secret is anything that you want to tightly control access to, such as API keys, passwords, or certificates. [Azure App Configuration](https://learn.microsoft.com/azure/azure-app-configuration/overview) is a managed service that helps developers centralize their application configurations. It provides a service to store, manage, and retrieve application settings and feature flags. You can also reference secrets stored in Azure Key Vault from Azure App Configuration.

We can leverage these two services to store our application configurations and secrets and make them available to our workloads running in the AKS cluster using native Kubernetes resources; [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/) and [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/).

### Provision Azure resources

In order to complete this section, you will need a few Azure resources, so use the Azure CLI to create the following resources.

#### Azure Key Vault setup

Run the following command to create an Azure Key Vault.

```bash
KV_NAME=$(az keyvault create \
--name mykeyvault$RANDOM \
--resource-group myresourcegroup \
--query name \
--output tsv)
```

Assign yourself the **Key Vault Secrets Administrator** role to the Azure Key Vault.

```bash
az role assignment create \
--role "Key Vault Administrator" \
--assignee $(az ad signed-in-user show --query id -o tsv) \
--scope $(az keyvault show --name $KV_NAME --query id -o tsv)
```

Run the following command to create a secret in the Azure Key Vault.

```bash
az keyvault secret set \
--vault-name $KV_NAME \
--name MySecret1 \
--value MySecretValue1
```

#### Azure App Configuration setup

Run the following command to create an Azure App Configuration store.

```bash
AC_NAME=$(az appconfig create \
--name myappconfig$RANDOM \
--resource-group myresourcegroup \
--query name \
--output tsv)
```

It's best practice to create a User-Assigned Managed Identity to access Azure resources. This identity will be used to access only the data in the Azure App Configuration store and the Azure Key Vault and nothing else.

```bash
AC_ID=$(az identity create \
--name $AC_NAME-id \
--resource-group myresourcegroup \
--query id \
--output tsv)
```

Create simple key-value pair in the Azure App Configuration store.

```bash
az appconfig kv set \
--name $AC_NAME \
--key MyKey1 \
--value MyValue1 \
--yes
```

Now add a key vault reference to the Azure App Configuration store. This will point to the secret that was created in the Azure Key Vault in the previous step.

```bash
az appconfig kv set-keyvault \
--name $AC_NAME \
--key MySecret1 \
--secret-identifier https://$KV_NAME.vault.azure.net/secrets/MySecret1 \
--yes
```

The Azure App Configuration store will have a reference to the secret in the Azure Key Vault and the intent is to use the user-assigned managed identity to access the secret in the key vault. However this identity does not have the necessary permissions yet.

Run the following command to allow the configuration store's managed identity to read secrets from the key vault.

```bash
az role assignment create \
--role "Key Vault Secrets User" \
--assignee $(az identity show --id $AC_ID --query principalId --output tsv) \
--scope $(az keyvault show --name $KV_NAME --query id --output tsv)
```

> [!HINT]
> You might be wondering "what about the role assignment for the Azure App Configuration store?" We'll get to that in the next section.

### Azure App Configuration Provider for Kubernetes

AKS offers an extension called the [Azure App Configuration Provider for Kubernetes](https://learn.microsoft.com/azure/aks/azure-app-configuration?tabs=cli) that allows you to sync configurations from Azure App Configuration to Kubernetes ConfigMaps and/or Kubernetes Secrets. This extension is not installed by default in AKS Automatic clusters, but in this lab environment the extension has been pre-installed in the AKS Automatic cluster for you.

Run the following command to verify that the Azure app config provider pods are running.

```bash
kubectl get pods -n azappconfig-system
```

### Passwordless authentication to Azure services

The Azure App Config Provider pods will reach out to the Azure App Configuration store to retrieve key value pairs and/or secrets. The best practice is to establish a passwordless connection between the AKS cluster and the Azure App Configuration store and you can achieve this by using [AKS Workload Identity](https://learn.microsoft.com/azure/aks/workload-identity-deploy-cluster) and leveraging the [AKS Service Connector](https://learn.microsoft.com/azure/service-connector/how-to-use-service-connector-in-aks). The AKS Service Connector will take care of manual tasks like setting up the necessary Azure RBAC, creating a [federated credential](https://learn.microsoft.com/graph/api/resources/federatedidentitycredentials-overview?view=graph-rest-1.0), creating a Kubernetes [ServiceAccount](https://kubernetes.io/docs/concepts/security/service-accounts/), and creating any firewall rules needed to communicate with the Azure service..

Run the following command to create an AKS Service Connector to connect the AKS cluster to the Azure App Configuration store.

```bash
az aks connection create appconfig \
--kube-namespace dev \
--name myakscluster \
--resource-group myresourcegroup \
--target-resource-group myresourcegroup \
--app-config $AC_NAME \
--workload-identity $AC_ID
```

> [!ALERT]
> This can take up to 5 minutes to complete.

This command will create a service connector to allow pods in the **dev** namespace to connect to the Azure App Configuration store using the User-Assigned Managed Identity that was created earlier. The service connector will grant the User-Assigned Managed Identity the necessary permissions to access the Azure App Configuration store and configure a federated credential on the managed identity that will allow the ServiceAccount assigned to the pod to authenticate via workload identity.

> [!HINT]
> The AKS Service Connector is a powerful feature that allows you to connect your application pods to Azure services without having to manage any credentials. For more information, refer to the [service connector documentation](https://learn.microsoft.com/azure/service-connector/overview#what-services-are-supported-by-service-connector).

### Config sync to Kubernetes

The Azure App Configuration Provider for Kubernetes extension also installed new Kubernetes [Custom Resource Definitions (CRDs)](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/) which is used to sync configurations from the Azure App Configuration store to Kubernetes ConfigMaps and optionally Kubernetes Secrets.

Before you deploy the sync configuration manifest, you will need to collect the Azure App Configuration store's endpoint and the Kubernetes ServiceAccount name.

Run the following command to get the Azure App Configuration store's endpoint.

```bash
AC_ENDPOINT=$(az appconfig show \
--name $AC_NAME \
--query endpoint \
--output tsv)
```

As mentioned above, we will use Workload Identity to connect to the Azure App Configuration store in a passwordless manner. Workload Identity is enabled by default in AKS Automatic clusters.

Run the following command to get the Kubernetes ServiceAccount name.

```bash
SA_NAME=$(kubectl get sa -n dev -o jsonpath='{.items[?(@.metadata.name!="default")].metadata.name}')
```

Using the values you collected, create a sync configuration manifest.

```bash
kubectl apply -n dev -f - <<EOF
apiVersion: azconfig.io/v1
kind: AzureAppConfigurationProvider
metadata:
  name: devconfigs
spec:
  endpoint: $AC_ENDPOINT
  configuration:
    refresh:
      enabled: true
      interval: 10s
      monitoring:
        keyValues:
        - key: MyKey1
  target:
    configMapName: myconfigmap
  auth:
    workloadIdentity:
      serviceAccountName: $SA_NAME
  secret:
    auth:
      workloadIdentity:
        serviceAccountName: $SA_NAME
    target:
      secretName: mysecret
EOF
```

The sync manifest above will sync the key-value pairs from the Azure App Configuration store to the Kubernetes ConfigMap. Every 10s the configurations will be refreshed and the key MyKey1 will be treated as the sentinel key and monitored for changes. When the value for MyKey1 changes in the Azure App Configuration store, the Kubernetes ConfigMap will be updated. The configuration store also has a secret reference to the Azure Key Vault secret MySecret1. The secret will be synced to the Kubernetes Secret. You could also enable a refresh interval for the secret to be updated just as we did for the key-value pairs, but for this lab, we will leave it as is.

After a minute or so, you can check to see if the key-value pairs in the configuration store have been synced to the Kubernetes ConfigMap.

```bash
kubectl get cm -n dev myconfigmap -o jsonpath='{.data}'
```

Also, check to see if the secret in the configuration store has been synced to the Kubernetes Secret.

```bash
kubectl get secret -n dev mysecret -o jsonpath='{.data.MySecret1}' | base64 -d
```

> [!KNOWLEDGE]
> While syncing secrets from Azure App Configuration to Kubernetes Secrets is supported, it is not best to keep secrets in Kubernetes Secrets because Kubernetes Secrets are not encrypted but rather base64 encoded. If you need to authenticate with Azure services from your applications, it is best to use AKS Workload Identity and Microsoft Entra ID for passwordless authentication.

The app config sync is set to refresh every 10 seconds and you can choose which key to listen for changes. In this case, we are only listening for changes to the Key1 configuration. If you update the value for Key1 in the Azure App Configuration store, you should see the value updated in the Kubernetes ConfigMap after the next refresh.

Run the following command to update the value for Key1 in the Azure App Configuration store.

```bash
az appconfig kv set \
--name $AC_NAME \
--key MyKey1 \
--value MyNewValue1 \
--yes
```

After 10 seconds, you can check to see if the configurations have been updated in the Kubernetes ConfigMap.

```bash
kubectl get cm -n dev myconfigmap -o jsonpath='{.data}'
```

Great job! You have successfully synced configurations from Azure App Configuration to Kubernetes ConfigMaps and Secrets.

===

## Scaling and workload scheduling

One key benefit of Kubernetes is its ability to scale workloads across a pool of nodes. One key differentiator of running Kubernetes in the cloud is its power to dynamically scale the entire node pool to accommodate more workloads and meet user demand. This guide aims to get you comfortable with the scaling capabilities of AKS Automatic and understand best practices for workload scheduling.

### Cluster autoscaling

With AKS Automatic, the [Node Autoprovision (NAP)](https://learn.microsoft.com/azure/aks/node-autoprovision?tabs=azure-cli) feature is enabled by default and acts as the cluster autoscaler. AKS Node Autoprovision is the Azure implementation of the [Karpenter project](https://karpenter.sh) which was developed by friends at AWS and [donated to the Cloud Native Computing Foundation (CNCF)](https://aws.amazon.com/blogs/containers/karpenter-graduates-to-beta/). In short, Karpenter is a Kubernetes controller that automates the provisioning, right-sizing, and termination of nodes in a Kubernetes cluster.

> [!NOTE]
> The term **Node Autoprovision (NAP)** may be used interchangeably with **Karpenter** in this lab.

When using an AKS Automatic cluster, a system node pool is automatically deployed to run essential components managed by AKS Automatic. As workloads are added or removed from the cluster, the Node Autoscaling (NAP) feature dynamically scales up or down the number of nodes to meet demand. Initially, only system nodes run in the cluster, but as workloads are deployed, NAP provisions new nodes to support them. Conversely, when workloads are deleted, NAP reduces the number of nodes to minimize costs. However, this process can leave pods in a pending state until a new node is available or cause disruptions during consolidation events. As a result, it’s essential to consider these factors when planning high availability for your workloads.

There are a few key Karpenter concepts to understand when working with NAP. Let's start by understanding the following concepts:

- [NodeClass](https://karpenter.sh/docs/concepts/nodeclasses/) - set of constraints that define the type of node that should be provisioned. For example, you can define a NodeClass that specifies the type of VM, the region, the availability zone, and the maximum number of nodes that can be provisioned. In AKS, a default AKSNodeClass is created for you which specifies the OS image (currently [AzureLinux](https://github.com/microsoft/azurelinux)), and OS disk size of 128GB.
- [NodePool](https://karpenter.sh/docs/concepts/nodepools/) - set of nodes that are provisioned based on a NodeClass. You can have multiple NodePools in a cluster, each with its own set of constraints. In AKS Automatic, the default NodePool is created for you. You can create additional NodePools with specific constraints if you have workloads that require specific VM attributes. For examples of various NodePool constraints, see the the [examples](https://github.com/Azure/karpenter-provider-azure/tree/main/examples/v1beta1) in the Karpenter Azure provider repository.
- [NodeClaim](https://karpenter.sh/docs/concepts/nodeclaims/) - request for a node that matches a set of constraints. When a NodeClaim is created, Karpenter will provision a node that matches the constraints specified in the NodeClaim, and thus, a VM is born!

As mentioned above, the default NodeClass and default NodePool are created for you. So you can start deploying workloads right away. The default NodeClass is fairly generic and should be able to handle most workloads.

You can view the default NodePool by running the following command.

```bash
kubectl get nodepools default -o yaml
```

You may want to create additional NodePools with specific constraints if you have teams that need to deploy workloads that require specific compute requirements.

Run the following command to create a new NodePool for the dev team.

```bash
kubectl apply -f - <<EOF
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  annotations:
    kubernetes.io/description: General purpose NodePool for dev workloads
  name: devpool
spec:
  disruption:
    budgets:
    - nodes: 100%
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never
  template:
    metadata:
      labels:
        team: dev
    spec:
      nodeClassRef:
        name: default
      taints:
        - key: team
          value: dev
          effect: NoSchedule
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values:
        - arm64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        - D
EOF
```

This NodePool manifest creates a new NodePool called **devpool** with the following specifications:

- The NodePool is labeled with **team=dev**
- The NodePool only supports **arm64** architecture
- The NodePool only supports **linux** operating system
- The NodePool only supports **on-demand** capacity type
- The NodePool only supports **D** Azure VM SKU family

It is important to know that the nodes in the dev NodePool will have a taint applied to them with the key **team=dev** and the effect **NoSchedule**. This means that only pods that have a toleration for the **team=dev** taint will be scheduled on the nodes in the dev NodePool.

Now that the dev team has their own NodePool, you can try scheduling a pod that tolerates the taint that will be applied to the dev nodes. Before we do that, let's import the product-service container image into the Azure Container Registry.

> [!HINT]
> Remember we created a new policy that only allows images from specified container registries and container images that are not from the approved container registries will be denied.

Run the following command to get the name of the Azure Container Registry.

```bash
ACR_NAME=$(az acr list \
--resource-group myresourcegroup \
--query "[0].name" \
--output tsv)
```

Run the following command to import the product-service container image into the Azure Container Registry.

```bash
az acr import \
--name $ACR_NAME \
--source ghcr.io/azure-samples/aks-store-demo/product-service:1.5.2 \
--image product-service:1.5.2
```

Run the following command to replace the existing product-service pod.

```bash
kubectl replace --force -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product-service
        image: $ACR_NAME.azurecr.io/product-service:1.5.2
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: team
                operator: In
                values:
                - dev
      tolerations:
      - key: "team"
        operator: "Equal"
        value: "dev"
        effect: "NoSchedule"
EOF
```

This pod manifests ensures that the workload will be scheduled on a dev team node with the **nodeSelectorTerms** spec and tolerates the **team=dev** taint that was specified in the nodepool manifest.

You can check to see if the pod has been scheduled by running the following command.

```bash
kubectl get po -n dev -l app=product-service -o wide
```

You should see the pod in **Pending** state. This is because the dev NodePool does not have any nodes provisioned yet. The AKS cluster will automatically provision a node in the dev NodePool to satisfy the pod's requirements.

Once the node has been provisioned, you will see the pod in **Running** state.

If you run the following command, you will be able to see a new node being provisioned.

```bash
kubectl get nodes -l karpenter.sh/registered=true -o custom-columns=NAME:'{.metadata.name}',OS:'{.status.nodeInfo.osImage}',ARCH:'{.status.nodeInfo.architecture}',SKU:'{.metadata.labels.karpenter\.azure\.com/sku-name}' -w
```

Once you see the new node being provisioned, press **Ctrl+C** to exit the watch then run the following command to see the pod in **Running** state.

```bash
kubectl get po -n dev -l app=product-service -o wide
```

With NAP, you can ensure that your dev teams have the right resources to run their workloads without having to worry about the underlying infrastructure. As demonstrated, you can create NodePools with specific constraints to handle different types of workloads. But it is important to remember that the workload manifests include the necessary scheduling attributes such as **nodeAffinity** and **tolerations** to ensure that the workloads are scheduled on the right nodes. Otherwise, they may be scheduled on the default NodePool which is fairly generic and welcomes all workloads.

When deploying workloads to Kubernetes, it is important to follow best practices to ensure that your workloads are scheduled efficiently and effectively. This includes setting resource requests and limits, using PodDisruptionBudgets, and setting pod anti-affinity rules.

Let's explore a few best practices for workload scheduling.

### Resource requests and Vertical Pod Autoscaler

When deploying workloads to Kubernetes, it is important to set resource requests and limits. Resource requests are used by the scheduler to find the best node to place the pod on. Resource limits are used to prevent a pod from consuming more resources than it should. By setting resource requests and limits, you can ensure that your workloads are scheduled efficiently and effectively. We saw an example of this earlier when we deployed a pod with resource requests and limits after seeing warnings about not having them set.

But what if you don't know what values to set for the resource requests and limits? This is where the [Vertical Pod Autoscaler (VPA)](https://learn.microsoft.com/azure/aks/vertical-pod-autoscaler) comes in. The VPA automatically adjusts the resource requests and limits for your workloads based on their usage.

In the previous section, we deployed the product-service sample app without any resource requests and limits. Run the following command to confirm there are no resource requests and limits set for the product-service.

```bash
kubectl describe po -n dev $(kubectl get pod -n dev -l app=product-service  -o jsonpath='{.items[0].metadata.name}') | grep -i requests -A2
```

Now, deploy a VerticalPodAutoscaler resource to automatically adjust the resource requests for the product-service.

```bash
kubectl apply -f - <<EOF
apiVersion: "autoscaling.k8s.io/v1"
kind: VerticalPodAutoscaler
metadata:
  name: product-service-vpa
  namespace: dev
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: product-service
EOF
```

Watch the pod for a few minutes and you should see the pod being restarted with the updated resource requests and limits.

```bash
kubectl get pod -l app=product-service -n dev -w
```

> [!ALERT]
> The VPA will evict pods only if the number of replicas is greater than 1. Otherwise, it will not evict the pod.

Once you see the pods being restarted, press **Ctrl+C** to exit the watch then run the following command to confirm the resource requests and limits have been set.

```bash
kubectl describe po -n dev | grep -i requests -A2
```

With requests in place, the scheduler can make better decisions about where to place the pod. The VPA will also adjust the resource requests based on the pod's usage. This is also especially important when using pod autoscaling features like the Kubernetes [HorizontalPodAutoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) or [KEDA](https://keda.sh).

> [!KNOWLEDGE]
> KEDA is the Kubernetes-based Event Driven Autoscaler. With KEDA, you can scale your workloads based on the number of events in a queue, the length of a stream, or any other custom metric. It won't be covered in this lab, but the KEDA add-on for AKS is enabled by default in AKS Automatic clusters and you can learn more about it [here](https://learn.microsoft.com/azure/aks/keda-about).

### Dealing with disruptions

When deploying workloads to Kubernetes, it is important to ensure that your workloads are highly available and resilient to voluntary and involuntary disruptions. This is especially important when running workloads with Karpenter because nodes can be provisioned and deprovisioned automatically. There are a few best practices to follow to ensure that your workloads are highly available and resilient to disruptions.

One thing you can do is to set [PodDisruptionBudgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets) for your workloads. PodDisruptionBudgets are used to ensure that a certain number of pods are available during maintenance or disruptions. By setting PodDisruptionBudgets, you can ensure that your workloads are not abruptly terminated during maintenance or node scale down events.

The YAML spec for a PodDisruptionBudget is relatively easy to write and understand. But if you are not sure of how to write one, you can use [Microsoft Copilot for Azure](https://learn.microsoft.com/azure/copilot/overview) to generate the YAML for you.

Follow these steps to create a PodDisruptionBudget for the product-service running in the dev namespace.

- Navigate to your AKS cluster in the Azure Portal
- Under the **Kubernetes resources** section, click on **Workloads**, then click on the **+ Create** button to expand the dropdown
- Click on the **Apply a YAML** button. Here you will be presented with a blank YAML editor
- Put your cursor in the editor and press **Alt+I** to open the prompt dialog
- In the textbox type the following text and press the **Enter** key
  ```text
  create a pod disruption budget for the product-service running in the dev namespace to run at least 1 replica at all times
  ```
- You will see the YAML generated for you
- Click **Accept**
- Click the **Dry-run** button to ensure the YAML is valid
- Click **Add** button

Great! So now that you have a PodDisruptionBudget in place, you can be sure that at least one replica of the product-service will be available at all times. This is especially important when running workloads with Karpenter because it will try to consolidate as much as possible.

### More Karpenter features

There are other ways to deal with Karpenter's desire to consolidate nodes and still maintain a healthy app. Karpenter also supports [Consolidation Policies](https://karpenter.sh/docs/concepts/disruption/#consolidation) which allows you to customize the consolidation behavior. You can also set [node disruption budgets](https://karpenter.sh/docs/concepts/disruption/#nodepool-disruption-budgets) in the NodePool manifest to specify the percentage of nodes that can be consolidated at a time. Lastly, if you want to simply prevent a pod or node from being disrupted, you can use the **karpenter.sh/do-not-disrupt: true** annotation at the [pod level](https://karpenter.sh/docs/concepts/disruption/#pod-level-controls) or at the [node level](https://karpenter.sh/docs/concepts/disruption/#node-level-controls).

### More on affinity and anti-affinity

[Affinity and anti-affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) in Kubernetes is a way for you to influence the scheduling of pods in a Kubernetes cluster. We saw an example of this earlier when we deployed a pod with node affinity and tolerations to ensure that the pod was scheduled on a node that matched the criteria. Pod anti-affinity is used to ensure that pods are not scheduled on the same node. If you noticed, the product-service deployment included three replicas but they were all scheduled on the same node.

Go back to your terminal and confirm this by running the following command:

```bash
kubectl get po -n dev -l app=product-service -o wide
```

If a node hardware failure occurs, all three replicas will be disrupted at the same time even with the PodDisruptionBudget in place. To ensure that the replicas are spread across different nodes, you can set pods anti-affinity rules.

Run the following command to replace the product-service deployment with pod anti-affinity rules in place.

```bash
kubectl replace --force -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product-service
        image: $ACR_NAME.azurecr.io/product-service:1.5.2
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: team
                operator: In
                values:
                - dev
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - product-service
              topologyKey: "kubernetes.io/hostname"
      tolerations:
      - key: "team"
        operator: "Equal"
        value: "dev"
        effect: "NoSchedule"
EOF
```

In this updated deployment manifest, we added a **podAntiAffinity** field to ensure that the replicas are scheduled on different nodes. The **topologyKey** field specifies the key of the node label that the anti-affinity rule should be applied to. In this case, we are using the **kubernetes.io/hostname** key which is the hostname of the node.

Run the following command to watch the pods and confirm that the replicas are scheduled on different nodes.

```bash
kubectl get po -n dev -l app=product-service -o wide -w
```

Once you see the pods being scheduled on different nodes, press **Ctrl+C** to exit the watch.

### Pod topology spread constraints

To take the concept of spreading pods across nodes even further, you can use [Pod topology spread constraints](https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/) on top of pod anti-affinity rules. Pod topology spread constraints are used to ensure that pods are spread across different fault domains such as [Azure availability zones](https://learn.microsoft.com/azure/reliability/availability-zones-overview?tabs=azure-cli). With AKS Automatic, one of its requirements is to ensure the region its being deployed to supports availability zones. Therefore, you can be sure that the nodes provisioned by Karpenter can be spread across different availability zones.

Let's take a look at the availability zones of the nodes in the dev NodePool. Run the following command to get the nodes in the dev NodePool and their availability zones.

```bash
kubectl get nodes -l karpenter.sh/nodepool=devpool -o custom-columns=NAME:'{.metadata.name}',OS:'{.status.nodeInfo.osImage}',SKU:'{.metadata.labels.karpenter\.azure\.com/sku-name}',ZONE:'{.metadata.labels.topology\.kubernetes\.io/zone}'
```

In the output, you will see the nodes and their availability zones. The availability zones is denoted by a dash and a number following the region name. For example, **eastus-1**, **eastus-2**, and **eastus-3** are the availability zones in the **eastus** region.

Chances are that the nodes are already spread across different availability zones or you may see that all the nodes are in the same availability zone. You're really leaving it up to chance but to ensure that the pods are spread across different availability zones, you can set pod topology spread constraints.

Run the following command to delete the product-service deployment.

```bash
kubectl delete deployment product-service -n dev
```

Run the following command to watch the nodes in the dev NodePool get deleted.

```bash
kubectl get nodes -l karpenter.sh/nodepool=devpool -w
```

When you see that all the nodes in the dev NodePool are deleted, press **Ctrl+C** to exit the watch.

Run the following command to re-deploy the product-service deployment with pod topology spread constraints.

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product-service
        image: $ACR_NAME.azurecr.io/product-service:1.5.2
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: team
                operator: In
                values:
                - dev
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - product-service
              topologyKey: "kubernetes.io/hostname"
      tolerations:
      - key: "team"
        operator: "Equal"
        value: "dev"
        effect: "NoSchedule"
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: "topology.kubernetes.io/zone"
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: product-service
EOF
```

Here, the pod topology spread constraints will ensure that the pods are spread across different availability zones as the topology key is set to **topology.kubernetes.io/zone**. The **maxSkew** field specifies the maximum difference between the number of pods in any two zones. The **whenUnsatisfiable** field specifies what action to take if the constraint cannot be satisfied. In this case, we set it to **DoNotSchedule** which means that the pod will not be scheduled if the constraint cannot be satisfied. More information on spreading pods across different zones can be found [here](https://learn.microsoft.com/azure/aks/aks-zone-resiliency#ensure-pods-are-spread-across-azs).

Run the following command and you should start to see the nodes coming up in different availability zones.

```bash
kubectl get nodes -l karpenter.sh/nodepool=devpool -o custom-columns=NAME:'{.metadata.name}',OS:'{.status.nodeInfo.osImage}',SKU:'{.metadata.labels.karpenter\.azure\.com/sku-name}',ZONE:'{.metadata.labels.topology\.kubernetes\.io/zone}' -w
```

Once you see the nodes coming up in different availability zones, press **Ctrl+C** to exit the watch.

Now, run the following command to watch the pods and confirm that the replicas are scheduled across different availability zones.

```bash
kubectl get po -n dev -l app=product-service -o wide
```

Excellent! You have now know about some of the best practices for workload scheduling in Kubernetes to ensure that your workloads are scheduled efficiently and effectively.

===

## Troubleshooting workloads

Let's face it. Applications will fail. Being able to quickly identify and mitigate issues is crucial and in this section, you will become familiar with common kubernetes troubleshooting techniques and lean heavily on Microsoft Copilot for Azure to help uncover and solve problems.

### Troubleshooting with Azure Copilot

[Microsoft Copilot for Azure](https://learn.microsoft.com/azure/copilot/overview) is a tool built into the Azure portal that enables you to diagnose and troubleshoot issues. It is not only limited to AKS but you can use it to help troubleshoot any issues with your Azure resources. The Azure Copilot provides a guided experience to lead you through the troubleshooting process and helps you understand concepts by offering explanations, suggestions, and resource URLs to learn more.

#### Find the issue

In the Azure Portal, navigate to your AKS cluster and click on the Copilot button found at the top of the page. A panel will open on the right side of the screen and you will be presented with some suggested prompts.

Ask the Copilot:

```text
How is the health of my pods?
```

You should be presented with a kubectl command that you can run to get the status of your pods.

Click the **Yes** button to execute the command from the Run command page.

In the Run command page, the kubectl command will be pre-populated in the textbox at the bottom of the page. Click on **Run** to execute the command. You will see the output of the kubectl command in the main panel.

Scroll through the output and see if you can spot the issue.

> [!HINT]
> There is a problem with the ai-service pod.

#### Find the solution

Ask the Copilot:

```text
I see the ai-service pod in the dev namespace with CrashLoopBackOff status. What does that mean?
```

The Copilot should provide you with an explanation of what the CrashLoopBackOff status means and how to troubleshoot it.

You were not specific with the pod name so the Copilot gave you a general command to run, so re-prompt the Copilot to restate the commands by giving it the exact pod name `The exact pod name is ai-service-xxxxx. What commands should I run again?` (replace the xxxxx with the actual pod name).

> [!HINT]
> Some of the commands may include a **Run** button that can enable the Azure Cloud Shell, don't use this as you'd need to re-authenticate from within the Cloud Shell. Instead, copy the **kubectl describe** pod command and run it in the Run command window to get more information about the pod.

The **kubectl describe** command will provide you with more information about the pod including the events that led to the CrashLoopBackOff status. You might get a little more information about the issue if you look through the pod logs.

The Copilot should have also provided you with a **kubectl logs** command to get the logs of the pod.

Run that command to get the logs.

You should see that the ai-service pod is failing because it is missing environment variables that are required to connect to Azure OpenAI. Do you have an Azure OpenAI service running? If you are not sure, you can ask the Copilot `Do I have an Azure OpenAI service running?`

The Copilot will provide you with an [Azure Resource Graph](https://learn.microsoft.com/azure/governance/resource-graph/overview) command and run it behind the scenes to determine if you have an Azure OpenAI service running.

It should have determined there is no Azure OpenAI service running.

You go back to your dev team and they tell you that they will need an Azure OpenAI service with the GPT-3.5 Turbo model to run the ai-service pod.

#### Implement the solution

Ask the Copilot:

```text
How do I create an Azure OpenAI service with the GPT-3.5 Turbo model?
```

> [!ALERT]
> The Azure Copilot may not always provide you with the exact commands to run but it will provide you with the necessary information to get you started.

The instructions should be very close to what you need. You can either follow the instructions and/or reference the docs it replies with or you can run the following commands to quickly create an Azure OpenAI service account.

```bash
AI_NAME=$(az cognitiveservices account create \
--name myaiservice$RANDOM \
--resource-group myresourcegroup \
--kind OpenAI \
--sku S0 \
--custom-domain myaiservice$RANDOM \
--query name \
--output tsv)
```

Next, run the following command to deploy a GPT-3.5 Turbo model.

```bash
az cognitiveservices account deployment create \
--name $AI_NAME \
--resource-group myresourcegroup \
--deployment-name gpt-35-turbo \
--model-name gpt-35-turbo \
--model-version "0301" \
--model-format OpenAI \
--sku-capacity 1 \
--sku-name "Standard"
```

> [!ALERT]
> The model version above may not be available in your region. You can the model availability [here](https://learn.microsoft.com/azure/ai-services/openai/concepts/models?tabs=python-secure#standard-deployment-model-availability)

The dev team also tells you that the ai-service pod uses a ConfigMap named **ai-service-configs** with the following environment variables to connect to the Azure OpenAI service.

- **AZURE_OPENAI_DEPLOYMENT_NAME** set to "gpt-35-turbo"
- **AZURE_OPENAI_ENDPOINT** set to the endpoint of the Azure OpenAI service
- **USE_AZURE_OPENAI** set to "True"

Run the following command to delete the existing ConfigMap.

```bash
kubectl delete configmap ai-service-configs -n dev
```

Run the following command to create a new ConfigMap with the Azure OpenAI service endpoint.

```bash
kubectl create configmap ai-service-configs -n dev --from-literal=AZURE_OPENAI_DEPLOYMENT_NAME=gpt-35-turbo --from-literal=AZURE_OPENAI_ENDPOINT=$(az cognitiveservices account show --name $AI_NAME --resource-group myresourcegroup --query properties.endpoint -o tsv) --from-literal=USE_AZURE_OPENAI=True
```

Additionally the ai-service pod uses a Secret named **ai-service-secrets** with the following variable to authenticate to the Azure OpenAI service.

- **OPENAI_API_KEY** set to the API key of the Azure OpenAI service

Run the following command to delete the existing Secret.

```bash
kubectl delete secret ai-service-secrets -n dev
```

Run the following command to create a new Secret with the Azure OpenAI service API key.

```bash
kubectl create secret generic ai-service-secrets -n dev --from-literal=OPENAI_API_KEY=$(az cognitiveservices account keys list --name $AI_NAME --resource-group myresourcegroup --query key1 -o tsv)
```

Finally, run the following command to re-deploy the ai-service pod.

```bash
kubectl rollout restart deployment ai-service -n dev
```

You should see the ai-service pod status change from CrashLoopBackOff status to Running after a few minutes.

#### Challenges

1. Based on what you have learned so far in this lab, can you leverage Azure App Configuration to store the environment variables for the ai-service pod and sync them to the Kubernetes ConfigMap and Secret?
2. How can you go about updating this to use passwordless authentication with AKS Workload Identity instead?

> [!HINT]
> A complete walkthrough of the solution can be found [here](https://learn.microsoft.com/azure/aks/open-ai-secure-access-quickstart)

### Troubleshooting with kubectl

The Azure Copilot gave you some pretty good suggestions to start troubleshooting with kubectl. The **kubectl describe** command is a great way to get more information about a pod. You can also use the **kubectl logs** command to get the logs of a pod. One thing to note about using the **kubectl logs** command is that it only works for pods that are running. If the pod is in a CrashLoopBackOff status, you may not be able to get the logs of the pod that failed. In this case you can use the **--previous** flag to get the logs of the previous container that failed.

Finally, be sure to checkout the [Troubleshooting Applications](https://kubernetes.io/docs/tasks/debug/debug-application/) guide found on the Kubernetes documentation site and the following resources for more information on troubleshooting AKS:

- [Work with AKS clusters efficiently using Microsoft Copilot in Azure](https://learn.microsoft.com/azure/copilot/work-aks-clusters)
- [Azure Kubernetes Service (AKS) troubleshooting documentation](https://learn.microsoft.com/troubleshoot/azure/azure-kubernetes/welcome-azure-kubernetes)
- [Set up Advanced Network Observability for Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/advanced-network-observability-cli?tabs=cilium)

===

## Conclusion

Congratulations! You have completed the workshop on operating AKS Automatic. You have learned how to create an AKS Automatic cluster, enforce custom policies, sync configurations to the cluster, scale workloads, and apply best practices for workload scheduling. You have also learned how to troubleshoot issues in AKS. You are now well-equipped to operate AKS Automatic clusters and ensure that your workloads are running efficiently and effectively.

This lab is also available at [https://aka.ms/aks/labs](https://aka.ms/aks/labs) along with others, so be sure to check out the site often for new labs and updates.

If you have any feedback or questions on AKS in general, please reach out to us at [https://aka.ms/aks/feedback](https://aka.ms/aks/feedback).

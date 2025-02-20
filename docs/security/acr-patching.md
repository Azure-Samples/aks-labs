---
sidebar_label: Securing AKS Applications with ACR Continuous Patching
sidebar_position: 3
title: Securing AKS Applications with ACR Continuous Patching
# type: workshop
# short_title: ACR Continuous Patching
# description: This lab explores securing Azure Kubernetes Service (AKS) clusters with Azure Container Registry (ACR) Continuous Patching. By completing this lab, you will learn how ACR Continuous Patching can secure and patch container images that cannot be rebuilt, such as third-party images, within your Kubernetes fleet.
# level: beginner
# authors:
#   - Johnson Shi
# contacts:
#   - "@johnsonshi"
# duration_minutes: 60
# tags: workshop, lab, labs, security, aks, acr
---

## Securing AKS Applications with ACR Continuous Patching

Azure Kubernetes Service (AKS) provides a powerful platform to build, deploy, and manage secure cloud-native applications effortlessly. With [**Azure Container Registry (ACR) Continuous Patching**](https://aka.ms/acr/patching), you can enhance the security of your AKS workloads by addressing operating system (OS)-level vulnerabilities in container images directly within the registry, without needing to rebuild the images from source code.

ACR Continuous Patching utilizes the open-source [Trivy](https://trivy.dev/) scanner to detect vulnerabilities and [Copa (Copacetic)](https://project-copacetic.github.io/copacetic/website/) to apply security updates, ensuring that your container images remain patched, up-to-date, and secure within the registry. This approach seamlessly integrates with AKS best practices for secure deployments, providing a robust security solution for deployed containerized workloads. This includes remediating vulnerabilities for various types of container images, including those you do not have source code access to perform a rebuild, such as vendor-supplied or open-source images.

By the end of this lab, you will understand how ACR Continuous Patching secures vulnerable container images, empowering you to maintain a more secure and reliable cloud-native environment within your AKS cluster.

## Objectives

By the end of this lab, you will be able to:

- Understand how to import a container image into Azure Container Registry (ACR) from an upstream registry.
- Deploy the imported image to an Azure Kubernetes Service (AKS) cluster.
- Run Trivy scans against container images in ACR to detect patchable OS-level vulnerabilities.
- Configure and run ACR Continuous Patching Workflows to generate a patched version of the vulnerable image within the registry on a specified schedule.
- Inspect and scan the newly generated patched image within the registry to observe the effects of ACR Continuous Patching.
- Update and apply your Kubernetes deployment to reference the newly patched image.

## Limitations

ACR Continuous Patching is currently in preview. The following limitations apply:

- Windows-based container images aren't supported.
- Only "OS-level" vulnerabilities that originate from system packages will be patched. This includes system packages in the container image managed by an OS package manager such as `apt` and `yum`. Vulnerabilities that originate from application packages, such as packages used by programming languages like Go, Python, and NodeJS are unable to be patched.
- End of Service Life (EOSL) images are not supported by Continuous Patching. EOSL images refer to container images where the underlying operating system is no longer offering updates, security patches, and technical support. Examples include container images based on older operating system versions such as Debian 8 and Fedora 28. EOSL images will be skipped from the ACR Continuous Patching despite having vulnerabilities. The recommended approach is to upgrade the underlying operating system of the vulnerable image to a supported version.

## Prerequisites

1. **Azure subscription** with permission to create resources.
2. **Azure CLI** (version 2.15.0+). If you need to install or update, see [Install the Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).
3. **kubectl** installed locally. If you need to install, you can run `az aks install-cli`. Alternatively, see [Install kubectl](https://kubernetes.io/docs/tasks/tools/).
4. **trivy** installed locally. If not installed, follow the instructions at [Trivy Installation](https://trivy.dev/latest/getting-started/installation/).
5. A **development environment** (POSIX-compliant local shell or Cloud Shell) for running Azure CLI commands.

> **Note**: If you choose to use Azure Cloud Shell, be aware that Cloud Shell currently does not come with Trivy pre-installed. You would need to install Trivy in your Cloud Shell or run those steps locally.

## Scenario Overview

0. **Lab Machine and Azure Cloud Shell Setup** (Optional Step - Needed if you are performing this from a fresh lab machine)
   - Login to Lab Machine.
   - Login to Azure Portal.
   - Login to Azure Cloud Shell on the Windows Terminal application.
   - Install `trivy` on the Azure Cloud Shell instance.

1. **Infrastructure Setup**
   - Create a resource group.
   - Create an ACR registry and an AKS cluster in the same resource group.
   - Attach the ACR to the AKS cluster so that AKS can pull images from it.

2. **Image Import & Deployment**
   - Import the publicly available `nginx` image into ACR.
   - Deploy this image to AKS as a Kubernetes Deployment.

3. **Vulnerability Detection**
   - Use Trivy to scan the imported `nginx` image in ACR for OS-level vulnerabilities.

4. **ACR Continuous Patching**
   - Enable ACR Continuous Patching by creating a workflow and pointing it to our `nginx` repository/tag.
   - Use the `--run-immediately` flag to generate a patched version of the image on demand instead of waiting for the specified Continuous Patching schedule to kick in.

5. **Inspecting New Patched Image**
   - Use Trivy to scan the newly generated patched image in ACR to see the effects of ACR Continuous Patching.

6. **Redeploy with Patched Image**
   - Update the Kubernetes deployment to reference the newly patched image.
   - Verify that the vulnerabilities are either mitigated or substantially reduced.

## Step 0: Lab Machine and Azure Cloud Shell Setup

If you are performing this on a lab machine, you must go through the following steps so that your lab machine is fully authenticated with Azure.

### Set Up Lab Machine

1. Log in to the lab machine with the provided credentials.

2. Open the Azure Portal at [https://portal.azure.com/#home](https://portal.azure.com/#home) in a browser.

3. Log in to Azure Portal with the provided credentials.

### Set Up Azure Cloud Shell

This lab requires running CLI tools within Azure Cloud Shell to perform the scenarios. Follow the steps to ensure Azure Cloud Shell is properly set up.

1. Open the Windows Terminal desktop application by hitting "Start", typing in "Terminal" in the Windows Search bar, and opening the application.

2. Open up an Azure Cloud Shell instance within the Windows Terminal desktop application. To do so, select the dropdown near the "+" button at the top of the window and select "Azure Cloud Shell" in the dropdown.

3. The Azure Cloud Shell instance will prompt you to sign in to Azure using a specific URL and a device code. Please go to [https://microsoft.com/devicelogin](https://microsoft.com/devicelogin) in a browser and authenticate using the device code shown in the Azure Cloud Shell instance.

4. Install `trivy` by running the following command in Azure Cloud Shell:

    ```bash
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s --
    ```

    Trivy will be installed at `$HOME/bin/trivy` for you to run.

5. Run the following so that `trivy` is in the `PATH` of the Azure Cloud Shell. Running this command will ensure that the `trivy` command can be run within the Azure Cloud Shell instance.

    ```bash
    export PATH=$HOME/bin:$PATH
    ```

6. The `kubectl` tool should already be installed in Azure Cloud Shell so no further installation steps are necessary.

7. Please do not close the Azure Cloud Shell instance or the Windows Terminal desktop application for the duration of the lab. Otherwise, you will have to perform the Azure Cloud Shell set up steps again.

## Step 1: Setup Azure Infrastructure

Create a new resource group, ACR registry, and AKS cluster. Afterwards, authenticate `trivy` and `kubectl` with the resources.

1. Set Environment Variables (optional, for convenience):

    ```bash
    export RANDOM_STR="$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
    export RG_NAME="acrpatching-$RANDOM_STR"
    export LOCATION="westus2" # This can be any Azure region.
    export ACR_NAME="myacr$RANDOM_STR" # ACR names must be globally unique.
    export AKS_NAME="myaks$RANDOM_STR"
    export IMAGE_VERSION="1.25"
    ```

2. Create the Resource Group:

    ```bash
    az group create --name $RG_NAME --location $LOCATION
    ```

3. Register for the Azure Container Registry Resource Provider:

    ```bash
    az provider register --namespace Microsoft.ContainerRegistry
    ```

    Confirm that the registration is successful:

    ```bash
    az provider show --namespace Microsoft.ContainerRegistry --query "registrationState"
    ```

    It should show output like the following:

    ```bash
    "Registered"
    ```

4. Create an ACR Registry:

    ```bash
    az acr create \
      --name $ACR_NAME \
      --resource-group $RG_NAME \
      --sku Premium \
      --location $LOCATION
    ```

5. Authenticate `trivy` with Azure Cloud Shell:

    ```bash
    az acr login --name $ACR_NAME --expose-token --output tsv --query accessToken \
        | trivy registry login \
            --username 00000000-0000-0000-0000-000000000000 \
            --password-stdin $ACR_NAME.azurecr.io
    ```

6. Register for the Azure Kubernetes Service Resource Provider:

    ```bash
    az provider register --namespace Microsoft.ContainerService
    ```

    Confirm that the registration is successful:

    ```bash
    az provider show --namespace Microsoft.ContainerService --query "registrationState"
    ```

    It should show output like the following:

    ```bash
    "Registered"
    ```

7. Create an AKS Cluster:

    ```bash
    az aks create \
      --name $AKS_NAME \
      --resource-group $RG_NAME \
      --attach-acr $ACR_NAME \
      --no-ssh-key \
      --location $LOCATION
    ```

8. Authenticate with the AKS cluster by getting its AKS Credentials:

    ```bash
    az aks get-credentials \
      --name $AKS_NAME \
      --resource-group $RG_NAME
    ```

## Step 2: Import & Deploy the Vulnerable Image

1. Import the container image into the ACR registry:

    ```bash
    az acr import \
      --name $ACR_NAME \
      --resource-group $RG_NAME \
      --source mcr.microsoft.com/mirror/docker/library/nginx:$IMAGE_VERSION \
      --image nginx:$IMAGE_VERSION
    ```

2. Confirm the image is now in your ACR:

    ```bash
    az acr repository show-tags \
      --name $ACR_NAME \
      --repository nginx
    ```

    You should see output similar to:

    ```bash
    [
      "1.25"
    ]
    ```

3. Deploy the image to the AKS cluster by using a Kubernetes deployment manifest pointing to this newly imported image:

    ```bash
    cat <<EOF > nginx-deployment.yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx-deployment
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          containers:
          - name: nginx
            image: $ACR_NAME.azurecr.io/nginx:$IMAGE_VERSION
            ports:
            - containerPort: 80
    EOF

    kubectl apply -f nginx-deployment.yaml
    kubectl rollout status deployment/nginx-deployment
    ```

4. Verify that the deployment is running:

    ```bash
    kubectl get pods
    ```

## Step 3: Scan the Image for Vulnerabilities

Before we enable continuous patching, let's inspect the imported image to see whether it has patchable OS-level vulnerabilities.

1. **Install `trivy`** (if not already installed). See [Trivy Installation](https://trivy.dev/latest/getting-started/installation/).

2. **Scan the Imported Image**: We must reference the image from our ACR, including its fully qualified domain name:

    ```bash
    trivy image --pkg-types os --ignore-unfixed $ACR_NAME.azurecr.io/nginx:$IMAGE_VERSION
    ```

    You should see a list of OS-related vulnerabilities. Example output might look like:

    ```bash
    ...
    Total: 17 (UNKNOWN: 0, LOW: 2, MEDIUM: 12, HIGH: 3, CRITICAL: 0)
    ...
    ```

    This confirms we have vulnerabilities in the imported image that can potentially be patched by ACR Continuous Patching, directly within the registry.

## Step 4: Enable ACR Continuous Patching

1. Install the Preview ACR Extension for ACR Continuous Patching. When prompted for confirmation, confirm the installation by typing in `y` and pressing Enter.

    ```bash
    az extension add --source https://acrcssc.z5.web.core.windows.net/acrcssc-1.1.1rc7-py3-none-any.whl
    ```

2. Create the ACR Continuous Patching configuration file:

    ```bash
    cat <<EOF > continuouspatching.json
    {
      "version": "v1",
      "tag-convention": "incremental",
      "repositories": [
        {
          "repository": "nginx",
          "tags": ["$IMAGE_VERSION"],
          "enabled": true
        }
      ]
    }
    EOF
    ```

    Key fields:
    - **version**: Use `"v1"` to specify the schema version of the Continuous Patching configuration file.
    - **tag-convention**: Supported values are either `"incremental"` or `"floating"`.
      - When `"incremental"` is chosen, each new Continuous Patch increments a numerical suffix (e.g., `-1`, `-2`, etc.) on the original tag. For instance, if the vulnerable image is `nginx:1.25`, the first run of ACR Continuous Patching creates `nginx:1.25-1` within the registry, and a second run on that same tag creates `nginx:1.25-2`.
      - When `"floating"` is chosen, a single mutable tag, `-patched`, will always reference the latest patched version of your image. For instance, if the vulnerable image is `nginx:1.25`, the first patch creates `nginx:1.25-patched`. With each subsequent ACR Continuous Patch run, the `-patched` tag will automatically update to point to the most recent patched image generated within your registry.
    - **repositories**: Points to the repository of the vulnerable container image.
    - **tags**  is an array of tags separated by commas. The wildcard  `*`  can be used to signify all tags within that repository.

3. Validate a dry run of ACR Continuous Patching:

    You can see what images would be patched by running a dry run. The `--schedule 1d` means the workflow repeats every day.

    ```bash
    az acr supply-chain workflow create \
      --registry $ACR_NAME \
      --resource-group $RG_NAME \
      --type continuouspatchv1 \
      --config ./continuouspatching.json \
      --schedule 1d \
      --dry-run
    ```

    The output shows which images match your config. If everything looks correct, proceed.

4. Enable the ACR Continuous Patching schedule. Simultaneously, using the `--run-immediately` flag, we instruct ACR Continuous Patching to immediately scan and patch the image instead of waiting for the specified schedule to kick in.

    ```bash
    az acr supply-chain workflow create \
      --registry $ACR_NAME \
      --resource-group $RG_NAME \
      --type continuouspatchv1 \
      --config ./continuouspatching.json \
      --schedule 1d \
      --run-immediately
    ```

    Key fields:
    - **`--schedule 1d`**: This means that, after today, the next patch cycle will run once every day (aligning with the day multiples for the month).
    - **`--run-immediately`**: Forces a patch run now (instead of waiting for the scheduled day).

5. Observe the Patching Workflow (Optional):

    You can observe the newly created tasks in the Azure Portal:

    - Navigate to your container registry.
    - Under **Services**, click on **Tasks**.
    - You should see Tasks named `cssc-trigger-workflow`, `cssc-scan-image`, and `cssc-patch-image`.
    - Click on these Tasks to view the scanning and patching logs for ACR Continuous Patching.

    You can also check the logs using the CLI:

    ```bash
    az acr supply-chain workflow show \
      --registry $ACR_NAME \
      --resource-group $RG_NAME \
      --type continuouspatchv1
    ```

    Alternatively, you can also check logs with:

    ```bash
    az acr task list-runs -r $ACR_NAME -n cssc-scan-image
    az acr task list-runs -r $ACR_NAME -n cssc-patch-image
    ```

## Step 5: Inspect and Scan the New Patched Image

1. Confirm a new patched image is generated within the registry by looking for the incremental patch tag:

    After a few minutes, the patching workflow completes. List tags in your `nginx` repository:

    ```bash
    az acr repository show-tags \
      --name $ACR_NAME \
      --repository nginx
    ```

    Expected output:

    ```bash
    [
      "1.25",
      "1.25-1"
    ]
    ```

    The tag `1.25-1` refers to the newly patched image within the registry.

2. Scan the new patched image in the registry with `trivy` to see the security benefits of ACR Continuous Patching:

    ```bash
    trivy image --pkg-types os --ignore-unfixed $ACR_NAME.azurecr.io/nginx:$IMAGE_VERSION-1
    ```

    You should see output confirming that the new patched image has 0 fixable OS-level vulnerabilities, indicating that ACR Continuous Patching successfully remediated them.

## Step 6: Update Your Kubernetes Deployment

1. Deploy the Patched Image:

    Update the Kubernetes deployment to reference the `-1` incremental patch image:

    ```bash
    sed -i "s/$IMAGE_VERSION/$IMAGE_VERSION-1/" nginx-deployment.yaml

    kubectl apply -f nginx-deployment.yaml
    kubectl rollout status deployment/nginx-deployment
    ```

    Check that the relevant pods have been deployed and are running:

    ```bash
    kubectl get pods -l app=nginx -o wide
    ```

    You can use `kubectl describe` to describe one of the pods to confirm the pod is indeed running the incremental patch image.

    ```bash
    kubectl describe pod $(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')
    ```

## Summary

Congratulations! You have successfully:

- **Created** a resource group, ACR, and AKS cluster.
- **Imported** a vulnerable `nginx` image into ACR.
- **Deployed** the image to AKS and confirmed there are patchable OS-level vulnerabilities via **Trivy** scans.
- **Enabled** ACR Continuous Patching to automatically detect and patch OS-level vulnerabilities.
- **Inspected** the newly patched container image within the registry to see the security benefits of ACR Continuous Patching.
- **Redeployed** your Kubernetes workload to use the newly patched image.

### Key Takeaways

1. **OS-Level Vulnerabilities**: Trivy scanned your container images to detect patchable vulnerabilities in OS packages.
2. **Automated Remediation**: ACR Continuous Patching automatically creates new patched images, saving you from rebuilding images from the ground up.
3. **Incremental Tagging**: Our patching approach used `-1` suffix tags to preserve version history. Additional patches would yield `-2`, `-3`, etc.
4. **Scheduling**: You can choose how frequently ACR runs its patch cycle (e.g., `1d`, `7d`).
5. **Rolling Updates**: By updating your Kubernetes Deployment’s image tag, you can seamlessly roll out patched images without downtime.

### Documentation

- For more info on ACR Continuous Patching, see the [ACR Continuous Patching Documentation](https://aka.ms/acr/patching).

### Next Steps

- Integrate these steps into a CI/CD pipeline for fully automated vulnerability detection and remediation.
- Explore advanced scheduling or [floating tag-convention](https://project-copacetic.github.io/copacetic/website/) if you prefer a single always-updated `-patched` tag instead of incremental tags.

## Cleanup

If you no longer need the resources:

```bash
az group delete --name $RG_NAME --yes --no-wait
```

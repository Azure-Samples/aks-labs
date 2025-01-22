---
sidebar_position: 1
title: Advanced Storage Concepts
sidebar_label: Advanced Storage Concepts
# published: true # Optional. Set to true to publish the workshop (default: false)
# type: workshop # Required.
# title: AKS Deep Dives # Required. Full title of the workshop
# short_title: AKS Deep Dives # Optional. Short title displayed in the header
# description: This is a workshop for advanced AKS scenarios and day 2 operations # Required.
# level: intermediate # Required. Can be 'beginner', 'intermediate' or 'advanced'
# authors: # Required. You can add as many authors as needed
#   - "Paul Yu"
#   - "Brian Redmond"
#   - "Phil Gibson"
#   - "Russell de Pina"
#   - "Ken Kilty"
# contacts: # Required. Must match the number of authors
#   - "@pauldotyu"
#   - "@chzbrgr71"
#   - "@phillipgibson"
#   - "@russd2357"
#   - "@kenkilty"
# duration_minutes: 180 # Required. Estimated duration in minutes
# tags: kubernetes, azure, aks # Required. Tags for filtering and searching
# wt_id: WT.mc_id=containers-147656-pauyu
---

## Advanced Storage Concepts

### Storage Options

Azure offers rich set of storage options that can be categorized into two buckets: Block Storage and Shared File Storage. You can choose the best match option based on the workload requirements. The following guidance can facilitate your evaluation:

- Select storage category based on the attach mode.
  Block Storage can be attached to a single node one time (RWO: Read Write Once), while Shared File Storage can be attached to different nodes one time (RWX: Read Write Many). If you need to access the same file from different nodes, you would need Shared File Storage.
- Select a storage option in each category based on characteristics and user cases.

  **Block storage category:**
  | Storage option | Characteristics | User Cases |
  | :-------------------------------------------------------------------------------------------: | :----------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------------------------: |
  | [Azure Disks](https://learn.microsoft.com/azure/virtual-machines/managed-disks-overview) | Rich SKUs from low-cost HDD disks to high performance Ultra Disks. | Generic option for all user cases from Backup to database to SAP Hana. |
  | [Elastic SAN](https://learn.microsoft.com/azure/storage/elastic-san/elastic-san-introduction) | Scalability up to millions of IOPS, Cost efficiency at scale | Tier 1 & 2 workloads, Databases, VDI hosted on any Compute options (VM, Containers, AVS) |
  | [Local Disks](https://learn.microsoft.com/azure/virtual-machines/nvme-overview) | Priced in VM, High IOPS/Throughput and extremely low latency. | Applications with no data durability requirement or with built-in data replication support (e.g., Cassandra), AI training |

  **Shared File Storage category:**
  | Storage option | Characteristics | User Cases |
  | :--------------------------------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------: |
  | [Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-introduction) | Fully managed, multiple redundancy options. | General purpose file shares, LOB apps, shared app or config data for CI/CD, AI/ML. |
  | [Azure NetApp Files](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) | Fully managed ONTAP with high performance and low latency. | Analytics, HPC, CMS, CI/CD, custom apps currently using NetApp. |
  | [Azure Blobs](https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction) | Unlimited amounts of unstructured data, data lifecycle management, rich redundancy options. | Large scale of object data handling, backup |

- Select performance tier, redundancy type on the storage option.
  See the product page from above table for further evaluation of performance tier, redundancy type or other requirements.

### Orchestration Options

Besides invoking service REST API to ingest remote storage resources, there are two major ways to use storage options in AKS workloads: CSI (Container Storage Interface) drivers and Azure Container Storage.

#### CSI Drivers

Container Storage Interface is industry standard that enables storage vendors (SP) to develop a plugin once and have it work across a number of container orchestration systems. It’s widely adopted by both OSS community and major cloud storage vendors. If you already build storage management and operation with CSI drivers, or you plan to build cloud independent k8s cluster setup, it’s the preferred option.

#### Azure Container Storage

Azure Container Storage is built on top of CSI drivers to support greater scaling capability with storage pool and unified management experience across local & remote storage. If you want to simplify the use of local NVMe disks, or achieve higher pod scaling target,​ it’s the preferred option.

Storage option support on CSI drivers and Azure Container Storage:

|                                               Storage option                                               |                                        CSI drivers                                         | Azure Container Storage |
| :--------------------------------------------------------------------------------------------------------: | :----------------------------------------------------------------------------------------: | :---------------------: |
|          [Azure Disks](https://learn.microsoft.com/azure/virtual-machines/managed-disks-overview)          |     Support([CSI disks driver](https://learn.microsoft.com/azure/aks/azure-disk-csi))      |         Support         |
|       [Elastic SAN](https://learn.microsoft.com/azure/storage/elastic-san/elastic-san-introduction)        |                                            N/A                                             |         Support         |
|              [Local Disks](https://learn.microsoft.com/azure/virtual-machines/nvme-overview)               |                            N/A (Host Path + Static Provisioner)                            |         Support         |
|         [Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-introduction)          |     Support([CSI files driver](https://learn.microsoft.com/azure/aks/azure-files-csi))     |           N/A           |
| [Azure NetApp Files](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) | Support([CSI NetApp driver](https://learn.microsoft.com/azure/aks/azure-netapp-files-nfs)) |           N/A           |
|         [Azure Blobs](https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction)          | Support([CSI Blobs driver](https://learn.microsoft.com/azure/aks/azure-blob-csi?tabs=NFS)) |           N/A           |

### Use Azure Container Storage for Replicated Ephemeral NVMe Disk

Deploy a MySQL Server to mount volumes using local NVMe storage via Azure Container Storage and demonstrate replication and failover of replicated local NVMe storage in Azure Container Storage.

#### Setup Azure Container Storage

Follow the below steps to enable Azure Container Storage in an existing AKS cluster

Run the following command to set the new node pool name.

```bash
cat <<EOF >> .env
ACSTOR_NODEPOOL_NAME="acstorpool"
EOF
source .env
```

Run the following command to create a new node pool with **Standard_L8s_v3** VMs.

```bash
az aks nodepool add \
--cluster-name ${AKS_NAME} \
--resource-group ${RG_NAME} \
--name ${ACSTOR_NODEPOOL_NAME} \
--node-vm-size Standard_L8s_v3 \
--node-count 3
```

<div class="warning" data-title="Warning">

> You may or may not have enough quota to deploy Standard_L8s_v3 VMs. If you encounter an error, please try with a different VM size within the [L-family](https://learn.microsoft.com/azure/virtual-machines/sizes/storage-optimized/lsv2-series?tabs=sizebasic) or request additional quota by following the instructions [here](https://docs.microsoft.com/azure/azure-portal/supportability/resource-manager-core-quotas-request).

</div>

Update the cluster to enable Azure Container Storage.

```bash
az aks update \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--enable-azure-container-storage ephemeralDisk \
--azure-container-storage-nodepools ${ACSTOR_NODEPOOL_NAME} \
--storage-pool-option NVMe \
--ephemeral-disk-volume-type PersistentVolumeWithAnnotation
```

<div class="info" data-title="Note">

> This command can take up to 20 minutes to complete.

</div>

Run the following command and wait until all the pods reaches **Running** state.

```bash
kubectl get pods -n acstor --watch
```

<div class="info" data-title="Note">

> You will see a lot of activity with pods being created, completed, and terminated. This is expected as the Azure Container Storage is being enabled.

</div>

Delete the default storage pool created.

```bash
kubectl delete sp -n acstor ephemeraldisk-nvme
```

#### Create a replicated ephemeral storage pool

With Azure Container Storage enabled, storage pools can also be created using Kubernetes CRDs. Run the following command to deploy a new StoragePool custom resource. This will create a new storage class using the storage pool name prefixed with **acstor-**.

```bash
kubectl apply -f - <<EOF
apiVersion: containerstorage.azure.com/v1
kind: StoragePool
metadata:
  name: ephemeraldisk-nvme
  namespace: acstor
spec:
  poolType:
    ephemeralDisk:
      diskType: nvme
      replicas: 3
EOF
```

Now you should see the new storage class called **acstor-ephemeraldisk-nvme** has been created.

```bash
kubectl get sc
```

#### Deploy a MySQL server using new storage class

This setup is a modified version of [this guide](https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/).

Run the following command to download the MySQL manifest file.

```bash
curl -o acstor-mysql-config-services.yaml https://gist.githubusercontent.com/pauldotyu/f459c834558fd83a6254fae0eb23b1e6/raw/ad1b5db804060b18b3ea123db9189f1a2d56414b/acstor-mysql-config-services.yaml
```

Optionally, run the following command to take a look at the MySQL manifest file.

```bash
cat acstor-mysql-config-services.yaml
```

Run the following command to deploy the config map and services for the MySQL server.

```bash
kubectl apply -f acstor-mysql-config-services.yaml
```

Next, we'll deploy the MySQL server using the new storage class.

Run the following command to download the MySQL statefulset manifest file.

```bash
curl -o acstor-mysql-statefulset.yaml https://gist.githubusercontent.com/pauldotyu/f7539f4fc991cf5fc3ecb22383cb227c/raw/274b0747f1094db53869bcb0eb25faccf0f37a6a/acstor-mysql-statefulset.yaml
```

Optionally, run the following command to take a look at the MySQL statefulset manifest file.

```bash
cat acstor-mysql-statefulset.yaml
```

Run the following command to deploy the statefulset for MySQL server.

```bash
kubectl apply -f acstor-mysql-statefulset.yaml
```

#### Verify that all the MySQL server's components are available

Run the following command to verify that both mysql services were created (headless one for the statefulset and mysql-read for the reads).

```bash
kubectl get svc -l app=mysql
```

You should see output similar to the following:

```text
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
mysql        ClusterIP   None           <none>        3306/TCP   5h43m
mysql-read   ClusterIP   10.0.205.191   <none>        3306/TCP   5h43m
```

Run the following command to verify that MySql server pod is running. Add the **--watch** to wait and watch until the pod goes from Init to **Running** state.

```bash
kubectl get pods -l app=mysql -o wide --watch
```

You should see output similar to the following:

```text
NAME      READY   STATUS    RESTARTS   AGE   IP             NODE                                NOMINATED NODE   READINESS GATES
mysql-0   2/2     Running   0          1m34s  10.244.3.16   aks-nodepool1-28567125-vmss000003   <none>           <none>
```

<div class="info" data-title="Note">

> Keep a note of the node on which the **mysql-0** pod is running.

</div>

#### Inject data to the MySql database

Run the following command to run and exec into a mysql client pod to the create a database named **school** and a table **students**. Also, make a few entries in the table to verify persistence.

```bash
kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never -- \
mysql -h mysql-0.mysql <<EOF
CREATE DATABASE school;
CREATE TABLE school.students (RollNumber INT, Name VARCHAR(250));
INSERT INTO school.students VALUES (1, 'Student1');
INSERT INTO school.students VALUES (2, 'Student2');
EOF
```

#### Verify the entries in the MySQL server

Run the following command to verify the creation of database, table, and entries.

```bash
kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never -- \
mysql -h mysql-read -e "SELECT * FROM school.students"
```

You should see output similar to the following:

```text
+------------+----------+
| RollNumber | Name     |
+------------+----------+
|          1 | Student1 |
+------------+----------+
|          2 | Student2 |
+------------+----------+
```

#### Initiate the node failover

Now we will simulate a failover scenario by deleting the node on which the `mysql-0` pod is running.

Run the following command to get the current node count in the Azure Container Storage node pool.

```bash
NODE_COUNT=$(az aks nodepool show \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--name ${ACSTOR_NODEPOOL_NAME} \
--query count \
--output tsv)
```

Run the following command to scale up the Azure Container Storage node pool by 1 node.

```bash
az aks nodepool scale \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--name ${ACSTOR_NODEPOOL_NAME} \
--node-count $((NODE_COUNT+1)) \
--no-wait
```

Now we want to force the failover by deleting the node on which the **mysql-0** pod is running.

Run the following commands to get the name of the node on which the **mysql-0** pod is running.

```bash
POD_NAME=$(kubectl get pods -l app=mysql -o custom-columns=":metadata.name" --no-headers)
NODE_NAME=$(kubectl get pods $POD_NAME -o jsonpath='{.spec.nodeName}')
```

Run the following command to delete the node on which the **mysql-0** pod is running.

```bash
kubectl delete node $NODE_NAME
```

#### Observe that the mysql pods are running

Run the following command to get the pods and observe that the **mysql-0** pod is running on a different node.

```bash
kubectl get pods -l app=mysql -o wide --watch
```

Eventually you should see output similar to the following:

```text
NAME      READY   STATUS    RESTARTS   AGE   IP             NODE                                NOMINATED NODE   READINESS GATES
mysql-0   2/2     Running   0          3m25s  10.244.3.16   aks-nodepool1-28567125-vmss000002   <none>           <none>
```

<div class="info" data-title="Note">

> You should see that the **mysql-0** pod is now running on a different node than you noted before the failover.

</div>

#### Verify successful data replication and persistence for MySQL Server

Run the following command to verify the mount volume by injecting new data by running the following command.

```bash
kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never -- \
mysql -h mysql-0.mysql <<EOF
INSERT INTO school.students VALUES (3, 'Student3');
INSERT INTO school.students VALUES (4, 'Student4');
EOF
```

Run the command to fetch the entries previously inserted into the database.

```bash
kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never -- \
mysql -h mysql-read -e "SELECT * FROM school.students"
```

You should see output similar to the following:

```text
+------------+----------+
| RollNumber | Name     |
+------------+----------+
|          1 | Student1 |
+------------+----------+
|          2 | Student2 |
+------------+----------+
|          3 | Student3 |
+------------+----------+
|          4 | Student4 |
+------------+----------+
```

The output obtained contains the values entered before the failover. This shows that the database and table entries in the MySQL Server were replicated and persisted across the failover of **mysql-0** pod. The output also demonstrates that, newer entries were successfully appended on the newly spawned mysql server application.

Congratulations! You successfully created a replicated local NVMe storage pool using Azure Container Storage. You deployed a MySQL server with the storage pool's storage class and added entries to the database. You then triggered a failover by deleting the node hosting the workload pod and scaled up the cluster by one node to maintain three active nodes. Finally, you verified that the pre-failover data were successfully replicated and persisted, with new data added on top of the replicated data.

---

<!--
## Advanced Security Concepts

Security is a critical aspect of any application deployment and it can cover a wide range of areas. In this lab, we will focus on how to securely access resources in Azure from an AKS cluster using Workload Identity and the Secure Software Supply Chain. Workload Identity allows you to securely access Azure resources from your applications running on AKS without needing to manage credentials. When it comes to secure software supply chain, we will focus on using Notation to sign and verify container images. This will help ensure that the images you deploy are the ones you expect.
-->


## Update and Multi-Cluster Management

Maintaining your AKS cluster's updates is crucial for operational hygiene. Neglecting this can lead to severe issues, including losing support and becoming vulnerable to known CVEs (Common Vulnerabilities and Exposures) attacks. In this section, we will look and examine all tiers of your AKS infrastructure, and discuss and show the procedures and best practices to keep your AKS cluster up-to-date.

### API Server upgrades

AKS is a managed Kubernetes service provided by Azure. Even though AKS is managed, flexibility has been given to customer on controlling the version of the API server they use in their environment. As newer versions of Kubernetes become available, those versions are tested and made available as part of the service. As newer versions are provided, older versions of Kubernetes are phased out of the service and are no longer available to deploy. Staying within the spectrum of supported versions, will ensure you don't compromise support for your AKS cluster.

You have two options for upgrading your AKS API server, you can do manual upgrades at your own designated schedule, or you can configure cluster to subscribe to an auto-upgrade channel. These two options provides you with the flexibility to adopt the most appropriate choice depending on your organizations policies and procedures.

<div class="info" data-title="Note">

> When you upgrade a supported AKS cluster, you can't skip Kubernetes minor versions. For more information please see [Kubernetes version upgrades](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#kubernetes-version-upgrades)

</div>

#### Manually Upgrading the API Server and Nodes

The first step in manually upgrading your AKS API server is to view the current version, and the available upgrade versions.

```bash
az aks get-upgrades \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--output table
```

We can also, quickly look at the current version of Kubernetes running on the nodes in the nodepools by running the following:

```bash
kubectl get nodes
```

We can see all of the nodes in both the system and user node pools are at version **1.29.9** as well.

```text
NAME                                 STATUS   ROLES    AGE    VERSION
aks-systempool-14753261-vmss000000   Ready    <none>   123m   v1.29.9
aks-systempool-14753261-vmss000001   Ready    <none>   123m   v1.29.9
aks-systempool-14753261-vmss000002   Ready    <none>   123m   v1.29.9
aks-userpool-27827974-vmss000000     Ready    <none>   95m    v1.29.9
```

Run the following command to upgrade the current cluster API server, and the Kubernetes version running on the nodes, from version **1.29.9** to version **1.30.5**.

```bash
az aks upgrade \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--kubernetes-version "1.30.5"
```

<div class="info" data-title="Note">

> The az aks upgrade command has the ability to separate the upgrade operation to specify just the control plane and/or the node version. In this lab we will run the command that will upgrade both the control plan and nodes at the same time.

</div>

Follow the prompts to confirm the upgrade operation. Once the AKS API version has been completed on both the control plane and nodes, you will see a completion message with the updated Kubernetes version shown.

#### Setting up the auto-upgrade channel for the API Server and Nodes

A more preferred method for upgrading your AKS API server and nodes is to configure the cluster auto-upgrade channel for your AKS cluster. This feature allow you a "set it and forget it" mechanism that yields tangible time and operational cost benefits. By enabling auto-upgrade, you can ensure your clusters are up to date and don't miss the latest features or patches from AKS and upstream Kubernetes.

There are several auto-upgrade channels you can subscribe your AKS cluster to. Those channels include **none**, **patch**, **stable**, and **rapid**. Each channel provides a different upgrade experience depending on how you would like to keep your AKS clusters upgraded. For a more detailed explanation of each channel, please view the [cluster auto-upgrade channels](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster?tabs=azure-cli#cluster-auto-upgrade-channels) table.

For this lab demonstration, we will configure the AKS cluster to subscribe to the **patch** channel. The patch channel will automatically upgrades the cluster to the latest supported patch version when it becomes available while keeping the minor version the same.

Run the following command to set the auto-upgrade channel.

```bash
az aks update \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--auto-upgrade-channel patch
```

Once the auto-upgrade channel subscription has been enabled for your cluster, you will see the **upgradeChannel** property updated to the chosen channel in the output.

<div class="important" data-title="Important">

> Configuring your AKS cluster to an auto-upgrade channel can have impact on the availability of workloads running on your cluster. Please review the additional options available to [Customize node surge upgrade](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#customize-node-surge-upgrade).

</div>

### Node image updates

In addition to you being able to upgrade the Kubernetes API versions of both your control plan and nodepool nodes, you can also upgrade the operating system (OS) image of the VMs for your AKS cluster. AKSregularly provides new node images, so it's beneficial to upgrade your node images frequently to use the latest AKS features. Linux node images are updated weekly, and Windows node images are updated monthly.

Upgrading node images is critical to not only ensuring the latest Kubernetes API functionality will be available from the OS, but also to ensure that the nodes in your AKS cluster have the latest security and CVE patches to prevent any vulnerabilities in your environment.

#### Manually Upgrading AKS Node Image

When planning to manually upgrade your AKS cluster, it's good practice to view the available images.

Run the following command to view the available images for your the system node pool.

```bash
az aks nodepool get-upgrades \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--nodepool-name systempool
```

The command output shows the **latestNodeImageVersion** available for the nodepool.

Check the current node image version for the system node pool by running the following command.

```bash
az aks nodepool show \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--name systempool \
--query "nodeImageVersion"
```

In this particular case, the system node pool image is the most recent image available as it matches the latest image version available, so there is no need to do an upgrade operation for the node image. If you needed to upgrade your node image, you can run the following command which will update all the node images for all node pools connected to your cluster.

```bash
az aks upgrade \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--node-image-only
```

### Maintenance windows

Maintenance windows provides you with the predictability to know when maintenance from Kubernetes API updates and/or node OS image updates will occur. The use of maintenance windows can help align to your current organizational operational policies concerning when services are expected to not be available.

There are currently three configuration schedules for maintenance windows, **default**, **aksManagedAutoUpgradeSchedule**, and **aksManagedNodeOSUpgradeSchedule**. For more specific information on these configurations, please see [Schedule configuration types for planned maintenance](https://learn.microsoft.com/azure/aks/planned-maintenance?tabs=azure-cli#schedule-configuration-types-for-planned-maintenance).

It is recommended to use **aksManagedAutoUpgradeSchedule** for all cluster upgrade scenarios and aksManagedNodeOSUpgradeSchedule for all node OS security patching scenarios.

<div class="info" data-title="Note">

> The default option is meant exclusively for AKS weekly releases. You can switch the default configuration to the **aksManagedAutoUpgradeSchedule** or **aksManagedNodeOSUpgradeSchedule** configuration by using the `az aks maintenanceconfiguration update` command.

</div>

When creating a maintenance window, it is good practice to see if any existing maintenance windows have already been configured. Checking to see if existing maintenance windows exists will avoid any conflicts when applying the setting. To check for the maintenance windows on an existing AKS cluster, run the following command:

```bash
az aks maintenanceconfiguration list \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME}
```

If you receive **[]** as output, this means no maintenance windows exists for the AKS cluster specified.

#### Adding an AKS Cluster Maintenance Windows

Maintenance window configuration is highly configurable to meet the scheduling needs of your organization. For an in-depth understanding of all the properties available for configuration, please see the [Create a maintenance window](https://learn.microsoft.com/azure/aks/planned-maintenance?tabs=azure-cli#create-a-maintenance-window) guide.

The following command will create a **default** configuration that schedules maintenance to run from 1:00 AM to 2:00 AM every Sunday.

```bash
az aks maintenanceconfiguration add \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--name default \
--weekday Sunday \
--start-hour 1
```

### Managing Multiple AKS Clusters with Azure Fleet

Azure Kubernetes Fleet Manager (Fleet) enables at-scale management of multiple Azure Kubernetes Service (AKS) clusters. Fleet supports the following scenarios:

- Create a Fleet resource and join AKS clusters across regions and subscriptions as member clusters
- Orchestrate Kubernetes version upgrades and node image upgrades across multiple clusters by using update runs, stages, and groups
- Automatically trigger version upgrades when new Kubernetes or node image versions are published (preview)
- Create Kubernetes resource objects on the Fleet resource's hub cluster and control their propagation to member clusters
- Export and import services between member clusters, and load balance incoming layer-4 traffic across service endpoints on multiple clusters (preview)

For this section of the lab we will focus on two AKS Fleet Manager features, creating a fleet and joining member clusters, and propagating resources from a hub cluster to a member clusters.

You can find and learn about additional AKS Fleet Manager concepts and functionality on the [Azure Kubernetes Fleet Manager](https://learn.microsoft.com/azure/kubernetes-fleet/) documentation page.

#### Create Additional AKS Cluster

<div class="info" data-title="Note">

> If you already have an additional AKS cluster, in addition to your original lab AKS cluster, you can skip this section.

</div>

To understand how AKS Fleet Manager can help manage multiple AKS clusters, we will need to create an additional AKS cluster to join as a member cluster. The following commands and instructions will deploy an additional AKS cluster into the same Azure resource group as your existing AKS cluster. For this lab purposes, it is not necessary to deploy the additional cluster in a region and/or subscription to show the benefits of AKS Fleet Manager.

Run the following command to create a new environment variable for the name of the additional AKS cluster.

```bash
AKS_NAME_2="${AKS_NAME}-2"
```

Run the following command to create a new AKS cluster.

```bash
az aks create \
--resource-group ${RG_NAME} \
--name ${AKS_NAME_2} \
--no-wait
```

<div class="info" data-title="Note">

> This command will take a few minutes to complete. You can proceed with the next steps while the command is running.

</div>

#### Create and configure Access for a Kubernetes Fleet Resource with Hub Cluster

Since this lab will be using AKS Fleet Manager for Kubernetes object propagation, you will need to create the Fleet resource with the hub cluster enabled by specifying the --enable-hub parameter with the az fleet create command. The hub cluster will orchestrate and manage the Fleet member clusters. We will add the lab's original AKS cluster and the newly created additional cluster as a member of the Fleet group in a later step.

In order to use the AKS Fleet Manager extension, you will need to install the extension. Run the following command to install the AKS Fleet Manager extension.

```bash
az extension add --name fleet
```

Run the following command to create new environment variables for the Fleet resource name and reload the environment variables.

```bash
FLEET_NAME="myfleet${RANDOM}"
```

Next run the following command to create the Fleet resource with the hub cluster enabled.

```bash
FLEET_ID="$(az fleet create \
--resource-group ${RG_NAME} \
--name ${FLEET_NAME} \
--location ${LOCATION} \
--enable-hub \
--query id \
--output tsv)"
```

Once the Kubernetes Fleet hub cluster has been created, we will need to gather the credential information to access it. This is similar to using the `az aks get-credentials` command on an AKS cluster. Run the following command to get the Fleet hub cluster credentials.

```bash
az fleet get-credentials \
--resource-group ${RG_NAME} \
--name ${FLEET_NAME}
```

Now that you have the credential information merged to your local Kubernetes config file, we will need to configure and authorize Azure role access for your account to access the Kubernetes API for the Fleet resource.

Once we have all of the terminal environment variables set, we can run the command to add the Azure account to be a **Azure Kubernetes Fleet Manager RBAC Cluster Admin** role on the Fleet resource.

```bash
az role assignment create \
--role "Azure Kubernetes Fleet Manager RBAC Cluster Admin" \
--assignee ${USER_ID} \
--scope ${FLEET_ID}
```

#### Joining Existing AKS Cluster to the Fleet

Now that we have our Fleet hub cluster created, along with the necessary Fleet API access, we're now ready to join our AKS clusters to Fleet as member servers. To join AKS clusters to Fleet, we will need the Azure subscription path to each AKS object. To get the subscription path to your AKS clusters, you can run the following commands.

```bash
AKS_FLEET_CLUSTER_1_NAME="$(echo ${AKS_NAME} | tr '[:upper:]' '[:lower:]')"
AKS_FLEET_CLUSTER_2_NAME="$(echo ${AKS_NAME_2} | tr '[:upper:]' '[:lower:]')"
AKS_FLEET_CLUSTER_1_ID="$(az aks show --resource-group ${RG_NAME} --name ${AKS_FLEET_CLUSTER_1_NAME} --query "id" --output tsv)"
AKS_FLEET_CLUSTER_2_ID="$(az aks show --resource-group ${RG_NAME} --name ${AKS_FLEET_CLUSTER_2_NAME} --query "id" --output tsv)"
```

Run the following command to join both AKS clusters to the Fleet.

```bash
# add first AKS cluster to the Fleet
az fleet member create \
--resource-group ${RG_NAME} \
--fleet-name ${FLEET_NAME} \
--name ${AKS_FLEET_CLUSTER_1_NAME} \
--member-cluster-id ${AKS_FLEET_CLUSTER_1_ID}

# add the second AKS cluster to the Fleet
az fleet member create \
--resource-group ${RG_NAME} \
--fleet-name ${FLEET_NAME} \
--name ${AKS_FLEET_CLUSTER_2_NAME} \
--member-cluster-id ${AKS_FLEET_CLUSTER_2_ID}
```

Run the following command to verify both AKS clusters have been added to the Fleet.

```bash
kubectl get memberclusters
```

#### Propagate Resources from a Hub Cluster to Member Clusters

The ClusterResourcePlacement API object is used to propagate resources from a hub cluster to member clusters. The ClusterResourcePlacement API object specifies the resources to propagate and the placement policy to use when selecting member clusters. The ClusterResourcePlacement API object is created in the hub cluster and is used to propagate resources to member clusters. This example demonstrates how to propagate a namespace to member clusters using the ClusterResourcePlacement API object with a PickAll placement policy.

<div class="important" data-title="Important">

> Before running the following commands, make sure your `kubectl conifg` has the Fleet hub cluster as it's current context. To check your current context, run the `kubectl config current-context` command. You should see the output as **hub**. If the output is not **hub**, please run `kubectl config set-context hub`.

</div>

Run the following command to create a namespace to place onto the member clusters.

```bash
kubectl create namespace my-fleet-ns
```

Run the following command to create a ClusterResourcePlacement API object in the hub cluster to propagate the namespace to the member clusters.

```bash
kubectl apply -f - <<EOF
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: my-lab-crp
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      version: v1
      name: my-fleet-ns
  policy:
    placementType: PickAll
EOF
```

Check the progress of the resource propagation using the following command.

```bash
kubectl get clusterresourceplacement my-lab-crp
```

View the details of the ClusterResourcePlacement object using the following command.

```bash
kubectl describe clusterresourceplacement my-lab-crp
```

Now if you switch your context to one of the member clusters, you should see the namespace **my-fleet-ns** has been propagated to the member cluster.

```bash
kubectl config set-context ${AKS_FLEET_CLUSTER_1_NAME}
```

You should see the namespace **my-fleet-ns** in the list of namespaces.

This is a simple example of how you can use AKS Fleet Manager to manage multiple AKS clusters. There are many more features and capabilities that AKS Fleet Manager provides to help manage and operate multiple AKS clusters. For more information on AKS Fleet Manager, see the [Azure Kubernetes Fleet Manager](https://learn.microsoft.com/azure/kubernetes-fleet/) documentation.

---

<!--
## Summary

Congratulations! If you've completed all the exercises in this lab, you are well on your way to becoming an Azure Kubernetes Service (AKS) expert. You've learned how to create an AKS cluster, deploy applications, configure networking, and secure your cluster. You've also learned how to monitor your AKS cluster, manage updates, and even manage multiple AKS clusters with Azure Kubernetes Fleet Manager. Hopefully, you've gained a better understanding of how to manage and operate AKS clusters in a production environment.

The cloud is always evolving, and so is AKS. It's important to stay up-to-date with the latest features and best practices. The Azure Kubernetes Service (AKS) documentation is a great resource to learn more about AKS and stay up-to-date with the latest features and best practices. You can find the AKS documentation [here](https://learn.microsoft.com/azure/aks/) as well as the links listed below.
-->


### Additional Resources

- [Cluster operator and developer best practices to build and manage applications on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/best-practices)
- [AKS baseline architecture](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks/baseline-aks)
- [AKS baseline for multi-region clusters](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-multi-region/aks-multi-cluster)
- [Create a private Azure Kubernetes Service (AKS) cluster](https://learn.microsoft.com/azure/aks/private-clusters?tabs=default-basic-networking%2Cazure-portal)
- [Configure Azure CNI Powered by Cilium in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium)
- [Set up Advanced Network Observability for Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/advanced-network-observability-cli?tabs=cilium)
- [Install Azure Container Storage for use with Azure Kubernetes Service](https://learn.microsoft.com/azure/storage/container-storage/install-container-storage-aks)
- [Kubernetes resource propagation from hub cluster to member clusters](https://learn.microsoft.com/azure/kubernetes-fleet/concepts-resource-propagation)

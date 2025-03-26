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

## Objectives

In this workshop you will learn about the advanced storage concepts in Azure Kubernetes Service (AKS). You will learn about the different storage options available in Azure, how to use Azure Container Storage to manage local NVMe disks, and how to use Azure Container Storage to replicate local NVMe disks across multiple nodes. You will also learn about the different orchestration options available in Azure, including CSI drivers and Azure Container Storage.

## Prerequisites

Before starting this lab, please make sure that you have provisioned a lab environment. We suggest you complete *ONE* of the following labs before starting this lab:

- [Setting Up the Lab Environment](../getting-started/setting-up-lab-environment.md)
- [Kubernetes the Easy Way with AKS Automatic](../getting-started/aks-automatic.md)

## Storage Options

Azure offers rich set of storage options that can be categorized into two buckets: Block Storage and Shared File Storage. You can choose the best match option based on the workload requirements.

The following guidance can facilitate your evaluation:

- Select storage category based on the attach mode.
- Block Storage can be attached to a single node one time (RWO: Read Write Once), while Shared File Storage can be attached to different nodes one time (RWX: Read Write Many). If you need to access the same file from different nodes, you would need Shared File Storage.
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

## Orchestration Options

Besides invoking service REST API to ingest remote storage resources, there are two major ways to use storage options in AKS workloads: CSI (Container Storage Interface) drivers and Azure Container Storage.

### CSI Drivers

Container Storage Interface is industry standard that enables storage vendors (SP) to develop a plugin once and have it work across a number of container orchestration systems. It’s widely adopted by both OSS community and major cloud storage vendors. If you already build storage management and operation with CSI drivers, or you plan to build cloud independent k8s cluster setup, it’s the preferred option.

### Azure Container Storage

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

## Use Azure Container Storage for Replicated Ephemeral NVMe Disk

Deploy a MySQL Server to mount volumes using local NVMe storage via Azure Container Storage and demonstrate replication and failover of replicated local NVMe storage in Azure Container Storage.

### Setup Azure Container Storage

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

Where the environment variable `RG_NAME` is the set to the name of the resource group in your lab environment and the environment variable `AKS_NAME` is set to the name of the AKS cluster in your lab environment.

:::info

You may or may not have enough quota to deploy Standard_L8s_v3 VMs. If you encounter an error, please try with a different VM size within the [L-family](https://learn.microsoft.com/azure/virtual-machines/sizes/storage-optimized/lsv2-series?tabs=sizebasic) or request additional quota by following the instructions [here](https://docs.microsoft.com/azure/azure-portal/supportability/resource-manager-core-quotas-request).

:::

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

:::note

This command can take up to 20 minutes to complete.

:::

Run the following command and wait until all the pods reaches **Running** state.

```bash
kubectl get pods -n acstor --watch
```

You will see a lot of activity with pods being created, completed, and terminated. This is expected as the Azure Container Storage is being enabled.

Delete the default storage pool created.

```bash
kubectl delete sp -n acstor ephemeraldisk-nvme
```

### Create a replicated ephemeral storage pool

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

### Deploy a MySQL server using new storage class

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

### Verify that all the MySQL server's components are available

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

:::note

Keep a note of the node on which the **mysql-0** pod is running.

:::

### Inject data to the MySql database

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

### Verify the entries in the MySQL server

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

### Initiate the node failover

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

### Observe that the mysql pods are running

Run the following command to get the pods and observe that the **mysql-0** pod is running on a different node.

```bash
kubectl get pods -l app=mysql -o wide --watch
```

Eventually you should see output similar to the following:

```text
NAME      READY   STATUS    RESTARTS   AGE   IP             NODE                                NOMINATED NODE   READINESS GATES
mysql-0   2/2     Running   0          3m25s  10.244.3.16   aks-nodepool1-28567125-vmss000002   <none>           <none>
```

:::note

You should see that the **mysql-0** pod is now running on a different node than you noted before the failover.

:::

### Verify successful data replication and persistence for MySQL Server

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

## Summary

In this workshop, you explored advanced storage options in Azure Kubernetes Service (AKS), covering both Block Storage (Azure Disks, Elastic SAN, Local Disks) and Shared File Storage solutions (Azure Files, NetApp Files, Blobs). You learned how different orchestration methods like CSI drivers and Azure Container Storage can be leveraged depending on your requirements.

Through hands-on exercises, you successfully deployed a MySQL database using replicated local NVMe storage via Azure Container Storage. You demonstrated real-world resilience by simulating node failure and verifying data persistence across failover events - a critical capability for production workloads.

For more information, check out these resources:

- [Azure Container Storage Introduction](https://learn.microsoft.com/azure/storage/container-storage/container-storage-introduction)
- [Azure Storage Introduction](https://learn.microsoft.com/azure/storage/common/storage-introduction)
- [AKS Storage Best Practices](https://learn.microsoft.com/azure/aks/operator-best-practices-storage)

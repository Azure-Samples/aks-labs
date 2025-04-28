---
sidebar_position: 1
title: Introduction to Platform Engineering Labs
description: Introduction to Platform Engineering Labs
---

## Objectives

In this lab, you will be introduced to some of the key concepts and tools used in platform engineering. You will also deploy a control plane cluster using Azure Kubernetes Service (AKS). This cluster will serve as the foundation for your platform engineering projects in the labs following this one.

## Prerequisites

- Azure CLI -- Download it from [https://docs.microsoft.com/en-us/cli/azure/install-azure-cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- kubectl -- Download it from [https://kubernetes.io/docs/tasks/tools/](https://kubernetes.io/docs/tasks/tools/)
- Helm -- Download it from [https://helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/)
- A GitHub account. You can get one at [https://github.com/signup](https://github.com/signup)

## Introduction to Platform Engineering

Platform engineering is a discipline focused on designing, building, and maintaining the foundational infrastructure and tools that support software development and operations. It aims to create a stable, scalable, and efficient environment where developers can build, test, and deploy applications seamlessly.

Key aspects of platform engineering include:

- **Infrastructure Management** - This involves ensuring that servers, networks, and storage systems are reliable and performant. Platform engineers design and maintain the foundational infrastructure that supports applications, ensuring it can handle the demands of the organization and scale as needed.

- **Automation** - Focuses on implementing tools and processes to streamline repetitive tasks such as deployment, scaling, and configuration management. By automating these tasks, platform engineers increase efficiency, reduce human error, and free up time for more strategic work. This is achieved through the use of Infrastructure as Code (IaC) tools, CI/CD pipelines, and other automation frameworks. *GitOps* is a key practice in this area. GitOps is an operational framework that extends DevOps principles to infrastructure management. where Git repositories are used to manage infrastructure and application code, enabling version control and collaboration. You can learn more about GitOps from the links in the Resources section.

- **Self-Service** - Platform engineering promotes a self-service model where developers can access the tools and resources they need without relying on operations teams. This empowers developers to be more autonomous, speeding up the development process and reducing bottlenecks.

- **Monitoring and Observability** - This aspect involves setting up systems to continuously monitor application performance and health. Observability tools help detect issues early, providing insights into system behavior and enabling quick resolution of problems to maintain stability and reliability.

- **Security** - Security in platform engineering is about protecting the infrastructure from vulnerabilities and ensuring compliance with security standards. This includes implementing measures to safeguard data, prevent unauthorized access, and maintain the integrity of the platform.

- **Developer Experience** - Enhancing developer experience by providing tools, environments, and processes that make development smoother and more efficient. Platform engineers aim to reduce friction and improve productivity by creating a supportive and user-friendly environment for developers.

You will explore these concepts in the labs that follow.

## Resources

You can find more information about the tools and concepts used in this lab in the following resources:

- GitOps for Azure Kubernetes Service - [https://learn.microsoft.com/en-us/azure/architecture/example-scenario/gitops-aks/gitops-blueprint-aks](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/gitops-aks/gitops-blueprint-aks)

- ArgoCD - [https://argo-cd.readthedocs.io/en/stable/](https://argo-cd.readthedocs.io/en/stable/)

- Backstage - [https://backstage.io/](https://backstage.io/)
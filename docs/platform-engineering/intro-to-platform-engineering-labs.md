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

- **Automation** - Focuses on implementing tools and processes to streamline repetitive tasks such as deployment, scaling, and configuration management. By automating these tasks, platform engineers increase efficiency, reduce human error, and free up time for more strategic work.

- **Monitoring and Observability** - This aspect involves setting up systems to continuously monitor application performance and health. Observability tools help detect issues early, providing insights into system behavior and enabling quick resolution of problems to maintain stability and reliability.

- **Security** - Security in platform engineering is about protecting the infrastructure from vulnerabilities and ensuring compliance with security standards. This includes implementing measures to safeguard data, prevent unauthorized access, and maintain the integrity of the platform.

- **Developer Experience** - Enhancing developer experience by providing tools, environments, and processes that make development smoother and more efficient. Platform engineers aim to reduce friction and improve productivity by creating a supportive and user-friendly environment for developers.

We will explore these concepts in more detail in the labs that follow.

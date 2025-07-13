# AKS Labs

[![Deploy to GitHub Pages](https://github.com/Azure-Samples/aks-labs/actions/workflows/deploy.yml/badge.svg)](https://github.com/Azure-Samples/aks-labs/actions/workflows/deploy.yml)

A comprehensive collection of hands-on workshops and labs for learning Azure Kubernetes Service (AKS). These workshops provide practical experience with Kubernetes concepts, AKS features, and cloud-native technologies.

## 🚀 Quick Start

Visit the live documentation site: [https://azure-samples.github.io/aks-labs/](https://azure-samples.github.io/aks-labs/)

## 📚 What You'll Learn

This repository contains workshops covering:

- **Getting Started**: Kubernetes fundamentals and AKS basics
- **Networking**: Service mesh (Istio), Azure Container Networking, and network policies
- **Security**: Workload identity, supply chain security, and container registry patching
- **Operations**: Monitoring, scaling with KEDA/Karpenter, and cluster management
- **Platform Engineering**: GitOps with ArgoCD, Azure Service Operator, and Kubernetes Resource Operator
- **Storage**: Persistent volumes and advanced storage concepts
- **AI Workloads**: Running AI/ML workloads on AKS

## 🛠️ Development Setup

This site is built with [Docusaurus](https://docusaurus.io/). To run it locally:

### Prerequisites

- Node.js 18 or higher
- npm or yarn

### Installation

```bash
git clone https://github.com/Azure-Samples/aks-labs.git
cd aks-labs
npm install
```

### Local Development

```bash
npm start
```

This command starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.

### Build

```bash
npm run build
```

This command generates static content into the `build` directory and can be served using any static contents hosting service.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for details on how to:

- Report issues
- Submit workshop improvements
- Add new labs
- Review contributions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## 🔗 Related Resources

- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)
- [Azure Container Registry](https://docs.microsoft.com/azure/container-registry/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

# Quickstart Azure Kubernetes Service

This repository contains the code and configurations for deploying and managing applications and infrastructure using Kubernetes, Azure, and Docker. It is structured to support various stages of development, from infrastructure provisioning to application deployment.

## Repository structure

```bash
.github/
  workflows/
    docker-build-and-publish.yml  # GitHub Actions workflow for building and publishing Docker images
    infra-deployment.yml          # Workflow for deploying infrastructure
    k8s-deployment.yml            # Workflow for deploying applications to Kubernetes

aks-deploy/
  deployment.yaml  # Kubernetes Deployment manifest
  service.yaml     # Kubernetes Service manifest

app/
  app.py           # Python application source code
  Dockerfile       # Dockerfile for building the application image

azure-deploy/
  aks.bicep        # Azure Kubernetes Service (AKS) Bicep template
  main.bicep       # Main Bicep template for infrastructure deployment
  role.bicep       # Bicep template for setting up roles and permissions

.gitignore       # Git ignore rules
initial.ps1      # PowerShell script for initial Azure setup
LICENSE          # License information
README.md        # Documentation file (this file)

```

## How to use
### Initial Azure setup

## Contributing
Feel free to open issues or create pull requests for enhancements and fixes.

## License
This project is licensed under the terms of the LICENSE file.
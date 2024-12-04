# Quickstart Azure Kubernetes Service

This repository contains the code and configurations for deploying and managing applications and infrastructure using Kubernetes, Azure, and Docker. It is structured to support various stages of development, from infrastructure provisioning to application deployment.

## Repository structure

```bash
.github/
  workflows/
    docker-build-and-publish.yml    # GitHub Actions workflow for building and publishing Docker images
    infra-deployment.yml            # Workflow for deploying infrastructure
    k8s-deployment.yml              # Workflow for deploying applications to Kubernetes

aks-deploy/ 
  deployment.yaml                   # Kubernetes Deployment manifest
  service.yaml                      # Kubernetes Service manifest

app/  
  app.py                            # Python application source code
  Dockerfile                        # Dockerfile for building the application image

azure-deploy/ 
  aks.bicep                         # Azure Kubernetes Service (AKS) Bicep template
  main.bicep                        # Main Bicep template for infrastructure deployment
  role.bicep                        # Bicep template for setting up roles and permissions

.gitignore                          # Git ignore rules
initial.ps1                         # PowerShell script for initial Azure setup
LICENSE                             # License information
README.md                           # Documentation file (this file)

```

## How to use

### Clone the repository
Use this template to create a new repository. While this template is designed for AKS and ACR services in Azure, you can use it as a starting point for any similar project.

### Requirements
Ensure the following prerequisites are met before deploying the necessary resources using the scripts:

- An Azure account with an active Azure Subscription.
- An Azure Container Registry (https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-powershell)
- Azure PowerShell installed locally or access to the Azure Cloud Shell https://shell.azure.com/
- GitHub CLI installed locally or access to the Azure Cloud Shell.

Note: Azure Cloud Shell comes preinstalled with all the required tools.

### Initial Azure setup
The PowerShell function `Setup-AzureProject` automates the initial setup in Azure and GitHub. It performs the following tasks:

- Creates an Azure AD Service Principal for GitHub Actions workflows.
- Configures GitHub federated identity with Entra ID for secretless authentication in pipelines.
- Deploys the AKS resource group.
- Assigns necessary Azure RBAC roles for AKS and ACR operations.
- Configures GitHub repository secrets.

You can run the script locally or directly in the Azure Cloud Shell. Ensure you're authenticated to your Azure subscription using Azure PowerShell and to your GitHub repository with the GitHub CLI.

#### Dot source the PowerShell script
```PowerShell
. ./Setup-AzureProject.ps1
```

#### Call the function with your parameters

```PowerShell
Setup-AzureProject -DisplayName "Quickstart AKS" `
-AksSubscriptionId "<SubscriptionID>" `
-AksResourceGroup "rg-k8s-dev-001" `
-AksClusterName "latzok8s" `
-AksRegion "switzerlandnorth" `
-DeploymentManifestPath "./aks-deploy/deployment.yaml" `
-ServiceManifestPath "./aks-deploy/service.yaml" `
-DockerImageName "quickstart-aks-py" `
-AcrSubscriptionId "<SubscriptionID>" `
-AcrResourceGroup "rg-acr-prod-001" `
-AcrName "latzox" ` 
-SshKeyName "ssh-latzok8s-dev-001" ` 
-GitHubOrg "Latzox" ` 
-RepoName "quickstart-azure-kubernetes-service" ` 
-EnvironmentNames @('aks-prod', 'build', 'infra-preview', 'infra-prod')

```
Replace the example parameters above with your specific values.

### Run the GitHub Actions Pipelines
Preconfigured CI/CD pipelines in the .github/workflows/ directory handle resource deployments:

- Docker Build and Push: Builds a Docker image of the Python Flask app in /app and pushes it to ACR.
- Infra Deployment: Creates the AKS cluster and assigns necessary roles for pulling images from ACR.
- K8s Deployment: Deploys the Kubernetes application with the Docker image and exposes it using a public service.

#### Steps to Run Pipelines:
1. Go to Repository > Actions > Build and Push > Run workflow to execute the Docker Build and Push pipeline.
2. After a successful build, run the Infra Deployment workflow.
3. Finally, execute the K8s Deployment workflow.


### Testing
After deployment, explore the Azure Portal to review the resources created alongside the AKS cluster.

#### Useful Commands:
Check the Docker image in the registry:

```PowerShell
Get-AzContainerRegistryRepository -RegistryName <RegistryName> -Name <DockerImageName>
```

Check the AKS cluster details:

```PowerShell
Get-AzAksCluster -Name <AksClusterName> -ResourceGroupName <AksClusterResourceGroupName>
```

Connect to the AKS cluster:
```PowerShell
Import-AzAksCredential -Name <AksClusterName> -ResourceGroupName <AksClusterResourceGroupName>
```

Manage the cluster with kubectl:
```Bash
kubectl get pods
kubectl get service
```

#### Accessing the Deployed Application
After running kubectl get service, locate the External IP for the service named aks-service. Open this IP address in your browser to view the Python Flask app running in a container on Azure Kubernetes Service.

You have successfully deployed the solution! 🎉

## Contributing
Feel free to open issues or create pull requests for enhancements and fixes.

## License
This project is licensed under the terms of the LICENSE file.
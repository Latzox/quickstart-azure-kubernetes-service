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
Use this template by creating a new repository. Even tho this template uses aks and acr azure services, you can use this template as a starting point for your project.

### Requirements
Make sure you have the following set up. These are the requirements in order to deploy the neccessary resource with the scripts below.

- An Azure account with an active azure Subscription
- An Azure Container Registry (https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-powershell)
- Azure PowerShell installed locally or access to Azure Cloud Shell https://shell.azure.com/
- GitHub CLI installed locally or access to Azure Cloud Shell

The tools you need are preinstalled in every Azure Cloud Shell instance.

### Initial Azure setup
I created a PowerShell function that does the intial setup on Azure and GitHub. It does the following:

- Creates an Azure AD Service Principal for the GitHub Actions workflow.
- Configures GitHub federated identity with Entra ID for secretless authentication in your pipelines.
- Deploys the resource group for AKS.
- Assigns necessary Azure RBAC roles for AKS and ACR operations.
- Configures GitHub repository secrets.

You can use it by cloning your repository locally on your machine or into the Azure Cloud Shell. Make sure you're authenticated to your Azure subscription with Azure PowerShell and to your GitHub repo with GitHub CLI.

First, dot source the PowerShell script by running:

```PowerShell
. ./Setup-AzureProject.ps1
```

Now you can call the function by running:

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
The parameters are just an example of mine. You can replace it as you wish.

### Run the GitHub Actions Pipelines
I already created the necessary CI/CD pipelines in .github/workflows/ to deploy all resources.

- Docker Build and Push -> Creates a docker image of the Python flask app in /app.
- Infra Deployment -> Creates the AKS cluster and the role assignments for pulling images from the Azure Container registry
- K8s Deployment -> Creates a kubernetes application with the docker image and a service to expose the app to the public

First, run the Docker Build and Push pipeline by navigating to your repository>Actions>Build and Push>Run workflow. After successful execution you can proceed with the Infra deployment and the K8s as last.

### Testing
I suggest you to also have a look into the Azure Portal to see what kind of resources got deployed next to the AKS cluster itself.

Run the following command to view your docker image on the registry:
```PowerShell
Get-AzContainerRegistryRepository -RegistryName <RegistryName> -Name <DockerImageName>
```

Run the following command to view your AKS cluster:
```PowerShell
Get-AzAksCluster -Name <AksClusterName> -ResourceGroupName <AksClusterResourceGroupName>
```

Run the following command to connect to your AKS cluster:
```PowerShell
Import-AzAksCredential -Name <AksClusterName> -ResourceGroupName <AksClusterResourceGroupName>
```

Now you can manage the cluster with kubectl:
```Bash
kubectl get pods
kubectl get service
```
Now, with the service you'll see and external ip in your service named "aks-service". That's the IP you type into your browser to see the frontend of your Python flask app running in a container on the Azure Kubernetes Service.

You successfully deployed the solution.

## Contributing
Feel free to open issues or create pull requests for enhancements and fixes.

## License
This project is licensed under the terms of the LICENSE file.
###############################################################################
# Script Name: initial.ps1
# Description: Automates the deployment and configuration of AKS with ACR 
#              integration and GitHub federated identity for secure CI/CD workflows.
# Author: Latzox
# Date: 02-12-2024
# Version: 1.0
#
# Features:
# - Creates Azure AD Service Principal for authentication
# - Configures GitHub federated identity with Azure AD
# - Deploys the AKS resource group
# - Assigns necessary Azure RBAC roles for AKS and ACR integration
# - Configures GitHub repository secrets for authentication
#
# Requirements:
# - Authenticated with GitHub CLI
# - Authenticated with Azure PowerShell
#
# Usage:
# Execute this script in an authenticated PowerShell session.
# Ensure that GitHub CLI and Azure PowerShell modules are installed and configured.
###############################################################################


# Parameters for customization
param (
    [string]$DisplayName = "Quickstart AKS",
    [string]$AksSubscriptionId = "<subscriptionId>",
    [string]$AksResourceGroup = "rg-k8s-dev-001",
    [string]$AksClusterName = "latzok8s",
    [string]$AksRegion = "switzerlandnorth",
    [string]$AcrSubscriptionId = "<subscriptionId>",
    [string]$AcrResourceGroup = "rg-acr-prod-001",
    [string]$AcrName = "latzox",
    [string]$SshKeyName = "k8s-sshkey-dev-001",
    [string]$GitHubOrg = "Latzox",
    [string]$RepoName = "quickstart-azure-kubernetes-service",
    [string[]]$EnvironmentNames = @("aks-prod", "build", "infra-preview", "infra-prod"),
    [string]$DockerImageName = "quickstart-aks-py",
    [string]$DeploymentManifestPath = "./aks-deploy/deployment.yaml",
    [string]$ServiceManifestPath = "./aks-deploy/service.yaml"
)

$ErrorActionPreference = 'Stop'

# Helper function to set the subscription context
function Set-SubscriptionContext {
    param (
        [string]$SubscriptionId
    )
    Write-Host "Selecting subscription context for '$SubscriptionId'..."
    try {
        Select-AzSubscription -SubscriptionId $SubscriptionId
        Write-Host "Successfully set subscription context to '$SubscriptionId'."
    } catch {
        Write-Error "Failed to set subscription context: $_"
        exit 1
    }
}

# Step 1: Deploy the AKS Resource Group
Set-SubscriptionContext -SubscriptionId $AksSubscriptionId
try {
    Write-Host "Checking if AKS resource group exists..."
    $aksResourceGroupExists = Get-AzResourceGroup -Name $AksResourceGroup -ErrorAction SilentlyContinue

    if (-not $aksResourceGroupExists) {
        New-AzResourceGroup -Name $AksResourceGroup -Location $AksRegion
        Write-Host "AKS resource group '$AksResourceGroup' created successfully in region '$AksRegion'."
    } else {
        Write-Host "AKS resource group '$AksResourceGroup' already exists."
    }
} catch {
    Write-Error "Failed to create or verify the AKS resource group: $_"
    exit 1
}

# Step 2: Create Azure AD Service Principal
try {
    Write-Host "Checking for existing Azure AD Service Principal..."
    $existingSp = Get-AzADServicePrincipal -DisplayName $DisplayName -ErrorAction SilentlyContinue

    if (-not $existingSp) {
        $sp = New-AzADServicePrincipal -DisplayName $DisplayName -Role "Contributor" -Scope "/subscriptions/$AksSubscriptionId"
        Write-Host "Service Principal created successfully. AppId: $($sp.AppId)"
    } else {
        $sp = $existingSp
        Write-Host "Service Principal already exists. AppId: $($sp.AppId)"
    }
} catch {
    Write-Error "Failed to create or verify the Service Principal: $_"
    exit 1
}

# Step 3: Configure Federated Identity Credentials for GitHub Actions
try {
    Write-Host "Checking and creating Federated Identity Credentials for GitHub Actions..."
    
    # Ensure EnvironmentNames is provided as an array
    if (-not ($EnvironmentNames -is [System.Array])) {
        Write-Error "EnvironmentNames must be an array of environment names."
        exit 1
    }

    foreach ($envName in $EnvironmentNames) {
        Write-Host "Processing environment: $envName"
        
        # Check if the federated credential already exists for this environment
        $existingCredential = Get-AzADAppFederatedCredential -ApplicationObjectId (Get-AzADApplication -DisplayName "Quickstart AKS").Id -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq "OIDC-$envName" }
        
        if (-not $existingCredential) {
            Write-Host "Creating Federated Identity Credential for environment '$envName'..."
            $params = @{
                ApplicationObjectId = (Get-AzADApplication -DisplayName $DisplayName).Id
                Audience = "api://AzureADTokenExchange"
                Issuer = "https://token.actions.githubusercontent.com"
                Name = "OIDC-$envName"
                Subject = "repo:$GitHubOrg/$($RepoName):environment:$($envName)"
            }
            New-AzADAppFederatedCredential @params
            Write-Host "Federated Identity Credential for environment '$envName' configured successfully."
        } else {
            Write-Host "Federated Identity Credential for environment '$envName' already exists."
        }
    }
} catch {
    Write-Error "Failed to create or verify Federated Identity Credentials: $_"
    exit 1
}

# Step 4: Create an SSH Key in the AKS Resource Group
try {
    Write-Host "Checking for existing SSH key..."
    $sshKey = Get-AzSshKey -ResourceGroupName $AksResourceGroup -Name $SshKeyName -ErrorAction SilentlyContinue

    if (-not $sshKey) {
        $sshKey = New-AzSshKey -ResourceGroupName $AksResourceGroup -Name $SshKeyName
        Write-Host "SSH key created successfully."
    } else {
        Write-Host "SSH key '$SshKeyName' already exists in resource group '$AksResourceGroup'."
    }
} catch {
    Write-Error "Failed to create or verify SSH key: $_"
    exit 1
}

# Step 5: Assign Roles for ACR and AKS Access
Set-SubscriptionContext -SubscriptionId $AcrSubscriptionId
try {
    Write-Host "Checking and assigning roles for ACR and AKS access..."

    # Check and assign the custom "Role Assignment Creator" role
    $customRoleExists = Get-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionId "5d385d1a-a152-4e2d-b246-443d25882789" `
        -Scope "/subscriptions/$AcrSubscriptionId/resourceGroups/$AcrResourceGroup" -ErrorAction SilentlyContinue

    if (-not $customRoleExists) {
        New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionId "5d385d1a-a152-4e2d-b246-443d25882789" `
            -Scope "/subscriptions/$AcrSubscriptionId/resourceGroups/$AcrResourceGroup"
        Write-Host "'Role Assignment Creator' role assigned successfully."
    } else {
        Write-Host "'Role Assignment Creator' role already assigned."
    }

    # Check and assign the "AcrPush" role
    $acrPushExists = Get-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "AcrPush" `
        -Scope "/subscriptions/$AcrSubscriptionId/resourceGroups/$AcrResourceGroup/providers/Microsoft.ContainerRegistry/registries/$AcrName" `
        -ErrorAction SilentlyContinue

    if (-not $acrPushExists) {
        New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "AcrPush" `
            -Scope "/subscriptions/$AcrSubscriptionId/resourceGroups/$AcrResourceGroup/providers/Microsoft.ContainerRegistry/registries/$AcrName"
        Write-Host "'AcrPush' role assigned successfully."
    } else {
        Write-Host "'AcrPush' role already assigned."
    }
} catch {
    Write-Error "Failed to assign roles: $_"
    exit 1
}


# Step 6: Create the GitHub Actions Secrets
try {
    Write-Host "Creating or verifying GitHub Actions Secrets..."

    # Define the secrets and their values
    $secrets = @{
        "ENTRA_CLIENT_ID"           = $sp.AppId
        "ENTRA_SUBSCRIPTION_ID"     = $AksSubscriptionId
        "ENTRA_SUBSCRIPTION_ID_SS"  = $AcrSubscriptionId
        "ENTRA_TENANT_ID"           = (Get-AzContext).Tenant.Id
        "AKS_PUBLIC_SSH_KEY"        = $sshKey.publicKey
        "AZURE_ACR_NAME"            = $AcrName
        "DOCKER_IMAGE_NAME"         = $DockerImageName
        "AKS_RG"                    = $AksResourceGroup
        "AKS_CLUSTER_NAME"          = $AksClusterName
        "DEPLOYMENT_MANIFEST_PATH"  = $DeploymentManifestPath
        "SERVICE_MANIFEST_PATH"     = $ServiceManifestPath
    }

    foreach ($secretName in $secrets.Keys) {
        $secretValue = $secrets[$secretName]
        Write-Host "Creating or updating secret: $secretName"
        gh secret set $secretName --body $secretValue --repo "$($GitHubOrg)/$($RepoName)"
    }
    Write-Host "All secrets have been created or updated successfully."

} catch {
    Write-Error "Failed to create or update secrets or variables in GitHub: $_"
    exit 1
}

# Step 7: Cleanup - Remove autogenerated application secret
Write-Host "Checking application secrets..."
try {
    $secret = Get-AzADAppCredential -DisplayName $sp.DisplayName

    if ($secret) {
        Write-Host "Removing application secret..."
        Remove-AzADAppCredential -DisplayName "Quickstart AKS" -KeyId $secret.KeyId
    } else {
        Write-Host "There are no application secrets to remove. Continue."
    }
}
catch {
    Write-Error "Failed to remove application secret: $_"
    exit 1
}

Write-Host "Script execution completed successfully!"
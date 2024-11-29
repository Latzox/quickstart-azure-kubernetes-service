# Script to Set Up AKS with ACR Integration and Federated Identity
# Author: [Your Name]
# Date: [Today's Date]
# Description: This script creates an Azure AD service principal, configures federated identity for GitHub, deploys the AKS resource group, and assigns necessary roles for AKS and ACR integration across different subscriptions.

# Parameters for customization
param (
    [string]$DisplayName = "Quickstart AKS",
    [string]$AksSubscriptionId = "<YourSubscriptionID>",
    [string]$AksResourceGroup = "rg-k8s-dev-001",
    [string]$aksClusterName = "latzok8s",
    [string]$AksRegion = "switzerlandnorth",
    [string]$AcrSubscriptionId = "<YourSubscriptionID>",
    [string]$AcrResourceGroup = "rg-acr-dev-001",
    [string]$AcrName = "latzox",
    [string]$SshKeyName = "k8s-sshkey-dev-001",
    [string]$GitHubOrg = "Latzox",
    [string]$RepoName = "quickstart-azure-kubernetes-service",
    [string]$EnvironmentName = "aks-prod",
    [string]$dockerImageName = "quickstart-aks-py",
    [string]$deploymentManifestPath = "./aks-deploy/deployment.yaml",
    [string]$serviceManifestPath = "./aks-deploy/service.yaml"
)

# Helper function to set the subscription context
function Set-SubscriptionContext {
    param (
        [string]$SubscriptionId
    )
    Write-Host "Selecting subscription context for '$SubscriptionId'..." -ForegroundColor Cyan
    try {
        Select-AzSubscription -SubscriptionId $SubscriptionId
        Write-Host "Successfully set subscription context to '$SubscriptionId'." -ForegroundColor Green
    } catch {
        Write-Error "Failed to set subscription context: $_"
        exit 1
    }
}

# Step 1: Deploy the AKS Resource Group
Set-SubscriptionContext -SubscriptionId $AksSubscriptionId
try {
    Write-Host "Creating or ensuring existence of AKS resource group..." -ForegroundColor Cyan
    $aksResourceGroupExists = Get-AzResourceGroup -Name $AksResourceGroup -ErrorAction SilentlyContinue

    if (-not $aksResourceGroupExists) {
        New-AzResourceGroup -Name $AksResourceGroup -Location $AksRegion
        Write-Host "AKS resource group '$AksResourceGroup' created successfully in region '$AksRegion'." -ForegroundColor Green
    } else {
        Write-Host "AKS resource group '$AksResourceGroup' already exists." -ForegroundColor Yellow
    }
} catch {
    Write-Error "Failed to create or verify the AKS resource group: $_"
    exit 1
}

# Step 2: Create Azure AD Service Principal
try {
    Write-Host "Creating Azure AD Service Principal..." -ForegroundColor Cyan
    $sp = New-AzADServicePrincipal -DisplayName $DisplayName -Role "Contributor" -Scope "/subscriptions/$AksSubscriptionId"
    Write-Host "Service Principal created successfully. AppId: $($sp.AppId)" -ForegroundColor Green
} catch {
    Write-Error "Failed to create Service Principal: $_"
    exit 1
}

# Step 3: Configure Federated Identity Credential for GitHub Actions
try {
    Write-Host "Configuring Federated Identity Credential for GitHub Actions..." -ForegroundColor Cyan
    $params = @{
        ApplicationObjectId = $sp.Id
        Audience = "api://AzureADTokenExchange"
        Issuer = "https://token.actions.githubusercontent.com"
        Name = "OIDC"
        Subject = "repo:$GitHubOrg/$RepoName:environment:$EnvironmentName"
    }
    New-AzADAppFederatedCredential @params
    Write-Host "Federated Identity Credential configured successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to configure Federated Identity Credential: $_"
    exit 1
}

# Step 4: Create an SSH Key in the AKS Resource Group
try {
    Write-Host "Creating SSH key in the resource group..." -ForegroundColor Cyan
    New-AzSshKey -ResourceGroupName $AksResourceGroup -Name $SshKeyName
    Write-Host "SSH key created successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to create SSH key: $_"
    exit 1
}

# Step 5: Assign Roles for ACR and AKS Access
Set-SubscriptionContext -SubscriptionId $AcrSubscriptionId
try {
    Write-Host "Assigning roles for ACR and AKS access..." -ForegroundColor Cyan

    # Define a condition for role assignments
    $condition = "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {7f951dda-4ed3-4680-a7ca-43fe172d538d})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {7f951dda-4ed3-4680-a7ca-43fe172d538d}))"

    # Assign "Owner" role to the Service Principal in ACR resource group
    New-AzRoleAssignment -ApplicationId $sp.AppId -RoleDefinitionName "Owner" `
        -Scope "/subscriptions/$AcrSubscriptionId/resourceGroups/$AcrResourceGroup" `
        -Condition $condition -ConditionVersion "2.0"
    Write-Host "'Owner' role assigned successfully." -ForegroundColor Green

    # Assign "AcrPush" role to allow pushing images to ACR
    New-AzRoleAssignment -ApplicationId $sp.AppId -RoleDefinitionName "AcrPush" `
        -Scope "/subscriptions/$AcrSubscriptionId/resourceGroups/$AcrResourceGroup/providers/Microsoft.ContainerRegistry/registries/$AcrName"
    Write-Host "'AcrPush' role assigned successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to assign roles: $_"
    exit 1
}

# Step 6: Create the GitHub Actions Secrets
try {

    # Define the secrets and their values
    $secrets = @{
        "ENTRA_CLIENT_ID"           = $sp.AppId
        "ENTRA_SUBSCRIPTION_ID"     = $AksSubscriptionId
        "ENTRA_SUBSCRIPTION_ID_SS"  = $AcrSubscriptionId
        "ENTRA_TENANT_ID"           = (Get-AzContext).Tenant.Id
    }

    # Define the action variables and their values
    $variables = @{
        "AZURE_ACR_NAME"            = $AcrName
        "DOCKER_IMAGE_NAME"         = $dockerImageName
        "AKS_RG"                    = $AksResourceGroup
        "AKS_CLUSTER_NAME"          = $aksClusterName
        "DEPLOYMENT_MANIFEST_PATH"  = $deploymentManifestPath
        "SERVICE_MANIFEST_PATH"     = $serviceManifestPath
    }

    # Iterate through each secret and create it using the GitHub CLI
    foreach ($secretName in $secrets.Keys) {
        $secretValue = $secrets[$secretName]
        Write-Host "Creating secret: $secretName"
        gh secret set $secretName --body $secretValue --repo $RepoName
    }
    Write-Host "All secrets have been created successfully."

    # Iterate through each variable and create it using the GitHub CLI
    foreach ($variableName in $variables.Keys) {
        $variableValue = $variables[$variableName]
        Write-Host "Creating action variable: $variableName"
        gh variable set $variableName --body $variableValue --repo $RepoName
    }
    Write-Host "All action variables have been created successfully."

} catch {
    Write-Error "Failed to create secrets or variables in GitHub: $_"
    exit 1
}


Write-Host "Script execution completed successfully!" -ForegroundColor Green

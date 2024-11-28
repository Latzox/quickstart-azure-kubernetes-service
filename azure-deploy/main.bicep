targetScope = 'subscription'

@description('The name of the resource group.')
param aksRgName string = 'rg-k8s-dev-001'

@description('The name of the resource group.')
param acrRgName string = 'rg-acr-prod-001'

@description('The subscription ID of the Azure Kubernetes Service.')
param aksSubId string = '00000000-0000-0000-0000-000000000000'

@description('The resource group ID of the Azure Kubernetes Service.')
param acrSubId string = '00000000-0000-0000-0000-000000000000'

@description('The name of the Managed Cluster resource.')
param clusterName string = 'latzok8s'

@description('The location of the Managed Cluster resource.')
param location string = 'switzerlandnorth'

@description('Optional DNS prefix to use with hosted Kubernetes API server FQDN.')
param dnsPrefix string = 'latzok8s'

@description('Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize.')
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 32

@description('The number of nodes for the cluster.')
@minValue(1)
@maxValue(50)
param agentCount int = 1

@description('The size of the Virtual Machine.')
param agentVMSize string = 'Standard_B2s'

@description('User name for the Linux Virtual Machines.')
param linuxAdminUsername string = 'latzo'

@description('Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example \'ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm\'')
param sshRSAPublicKey string = ''

@description('Role definition ID for ACR pull role.')
param roleDefinitionId string = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource rg 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: aksRgName
  location: location
}

module aks 'aks.bicep' = {
  name: 'deploy-aks'
  scope: resourceGroup(aksSubId, aksRgName)
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: dnsPrefix
    osDiskSizeGB: osDiskSizeGB
    agentCount: agentCount
    agentVMSize: agentVMSize
    linuxAdminUsername: linuxAdminUsername
    sshRSAPublicKey: sshRSAPublicKey
  }
}

module roleAssignment 'role.bicep' = {
  name: 'deploy-roleAssignment'
  scope: resourceGroup(acrSubId, acrRgName)
  params: {
    roleDefinitionId: roleDefinitionId
    aksIdentityPrincipalId: aks.outputs.aksIdentityObjectId
  }
}

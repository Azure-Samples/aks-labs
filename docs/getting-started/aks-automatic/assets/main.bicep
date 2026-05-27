@description('The user object id for role assignments.')
@secure()
param userObjectId string

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: 'mylogs${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource metricsWorkspace 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: 'myprometheus${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
  location: resourceGroup().location
}

resource appInsights 'Microsoft.Insights/components@2025-01-23-preview' = {
  name: 'myappinsights${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
  location: resourceGroup().location
  kind: 'web'
  properties: {
    ApplicationId: 'myotel${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    Request_Source: 'IbizaAIExtension'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: logWorkspace.id
    AzureMonitorWorkspaceResourceId: metricsWorkspace.id
    AzureMonitorWorkspaceIngestionMode: 'Enabled'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: 'myregistry${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource azureKeyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: 'mykeyvault${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
  location: resourceGroup().location
  properties: {
    enableRbacAuthorization: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'myidentity${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
  location: resourceGroup().location
}

resource keyVaultSecretUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, managedIdentity.id, 'Key Vault Secrets User')
  scope: azureKeyVault
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}

resource keyVaultCertificateUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, managedIdentity.id, 'Key Vault Certificate User')
  scope: azureKeyVault
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba')
  }
}

resource keyVaultAdministratorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, userObjectId, 'Key Vault Administrator')
  scope: azureKeyVault
  properties: {
    principalId: userObjectId
    principalType: 'User'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
  }
}

resource openAI 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'OpenAI'
  location: resourceGroup().location
  name: 'myopenai${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
  properties: {
    customSubDomainName: 'myopenai${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'S0'
  }
}

resource gpt54Mini 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: openAI
  name: 'gpt-5.4-mini'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5.4-mini'
      version: '2026-03-17'
    }
  }
  sku: {
    capacity: 200
    name: 'GlobalStandard'
  }
}

output metricsWorkspaceId string = metricsWorkspace.id
output logWorkspaceId string = logWorkspace.id
output azureKeyVaultId string = azureKeyVault.id
output azureKeyVaultName string = azureKeyVault.name
output azureKeyVaultUri string = azureKeyVault.properties.vaultUri
output containerRegistryId string = containerRegistry.id
output containerRegistryUrl string = containerRegistry.properties.loginServer

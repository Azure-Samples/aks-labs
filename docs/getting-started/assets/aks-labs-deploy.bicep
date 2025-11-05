@description('The user object id for role assignments.')
@secure()
param userObjectId string

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
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

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: 'myregistry${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource azureKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
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

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
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

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'myappinsights${take(uniqueString(subscription().id, resourceGroup().id, deployment().name), 4)}'
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

output metricsWorkspaceId string = metricsWorkspace.id
output logWorkspaceId string = logWorkspace.id
output azureKeyVaultId string = azureKeyVault.id
output azureKeyVaultName string = azureKeyVault.name
output azureKeyVaultUri string = azureKeyVault.properties.vaultUri
output containerRegistryId string = containerRegistry.id
output containerRegistryUrl string = containerRegistry.properties.loginServer
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('The basename of the resource.')
param nameSuffix string

@description('The user object id for the cluster admin.')
@secure()
param userObjectId string

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'mylogs${take(uniqueString(nameSuffix), 4)}'
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

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'mylogs${take(uniqueString(nameSuffix), 4)}'
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

resource metricsWorkspace 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: 'myprometheus${take(uniqueString(nameSuffix), 4)}'
  location: resourceGroup().location
}

resource grafanaDashboard 'Microsoft.Dashboard/grafana@2023-09-01' = {
  name: 'mygrafana${take(uniqueString(nameSuffix), 4)}'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    grafanaIntegrations: {
      azureMonitorWorkspaceIntegrations: [
        {
          azureMonitorWorkspaceResourceId: metricsWorkspace.id
        }
      ]
    }
  }
}

resource grafanaAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, userObjectId, 'Grafana Admin')
  scope: grafanaDashboard
  properties: {
    principalId: userObjectId
    principalType: 'User'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '22926164-76b3-42b3-bc55-97df8dab3e41')
  }
}

resource mongo 'Microsoft.DocumentDB/databaseAccounts@2022-08-15' = {
  name: 'mymongo${take(uniqueString(nameSuffix), 4)}'
  kind: 'MongoDB'
  location: resourceGroup().location
  properties: {
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    locations: [
      {
        locationName: resourceGroup().location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    apiProperties: { serverVersion: '7.0' }
    capabilities: [ { name: 'EnableServerless' } ]
  }
}

resource db 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2024-12-01-preview' = {
  parent: mongo
  name: 'test'
  properties: {
    resource: {
      id: 'test'
    }
  }
}

resource mongoIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  location: resourceGroup().location
  name: 'mymongo${take(uniqueString(nameSuffix), 4)}-identity'
}

var documentDBAccountContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5bd9cd88-fe45-4216-938b-f97437e15450')
resource mongoIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mongo
  name: guid(mongo.id, mongoIdentity.id)
  properties: {
    principalId: mongoIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: documentDBAccountContributorRole
  }
}

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  location: resourceGroup().location
  name: 'myregistry${take(uniqueString(nameSuffix), 4)}'
  sku: {
    name: 'Basic'
  }
}

output grafanaId string = grafanaDashboard.id
output mongoId string = mongo.id
output appInsightsConnectionString string = appInsights.properties.ConnectionString

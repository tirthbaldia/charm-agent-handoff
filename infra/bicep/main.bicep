targetScope = 'subscription'

@description('Deployment location')
param location string = 'canadacentral'

@description('Resource group name for Charm hand-off stack')
param resourceGroupName string

@description('Environment tag')
param environment string = 'dev'

@description('Foundry account name')
param aiServicesAccountName string

@description('Foundry project name')
param foundryProjectName string

@description('SQL server name')
param sqlServerName string

@description('SQL database name')
param sqlDatabaseName string

@description('SQL admin login')
@secure()
param sqlAdminLogin string

@description('SQL admin password')
@secure()
param sqlAdminPassword string

@description('Key Vault name')
param keyVaultName string

@description('Logic App logger name')
param logicAppLoggerName string

@description('Logic App reader name')
param logicAppReaderName string

@description('SQL API connection name for Logic Apps')
param sqlApiConnectionName string = 'sql'

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: {
    app: 'charm-agent-handoff'
    env: environment
  }
}

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    appInsightsName: 'appi-${environment}-charm'
    workspaceName: 'law-${environment}-charm'
  }
}

module keyvault './modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    location: location
    keyVaultName: keyVaultName
  }
}

module ai './modules/ai-foundry.bicep' = {
  name: 'ai-foundry'
  scope: rg
  params: {
    location: location
    aiServicesAccountName: aiServicesAccountName
    foundryProjectName: foundryProjectName
  }
}

module sql './modules/sql.bicep' = {
  name: 'sql-stack'
  scope: rg
  params: {
    location: location
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
  }
}

module logicapps './modules/logicapps.bicep' = {
  name: 'logicapps-stack'
  scope: rg
  params: {
    location: location
    logicAppLoggerName: logicAppLoggerName
    logicAppReaderName: logicAppReaderName
    sqlApiConnectionName: sqlApiConnectionName
  }
}

output resourceGroupId string = rg.id
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output aiAccountEndpoint string = ai.outputs.aiAccountEndpoint

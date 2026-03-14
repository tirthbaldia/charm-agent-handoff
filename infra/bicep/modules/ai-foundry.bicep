targetScope = 'resourceGroup'

param location string
param aiServicesAccountName string
param foundryProjectName string

resource aiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServicesAccountName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: aiServicesAccountName
    publicNetworkAccess: 'Enabled'
  }
}

// Foundry project as child resource of the AI Services account.
resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2024-10-01' = {
  name: '${aiAccount.name}/${foundryProjectName}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

output aiAccountId string = aiAccount.id
output aiAccountEndpoint string = 'https://${aiServicesAccountName}.cognitiveservices.azure.com/'
output foundryProjectId string = foundryProject.id

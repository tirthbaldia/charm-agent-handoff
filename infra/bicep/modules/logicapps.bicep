targetScope = 'resourceGroup'

param location string
param logicAppLoggerName string
param logicAppReaderName string
param sqlApiConnectionName string

resource sqlConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: sqlApiConnectionName
  location: location
  properties: {
    displayName: 'SQL API Connection'
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/sql'
    }
    parameterValues: {}
  }
}

resource loggerWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppLoggerName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          type: 'Object'
          defaultValue: {}
        }
      }
      triggers: {}
      actions: {}
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          sql: {
            connectionId: sqlConnection.id
            connectionName: sqlConnection.name
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/sql'
          }
        }
      }
    }
  }
}

resource readerWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppReaderName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          type: 'Object'
          defaultValue: {}
        }
      }
      triggers: {}
      actions: {}
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          sql: {
            connectionId: sqlConnection.id
            connectionName: sqlConnection.name
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/sql'
          }
        }
      }
    }
  }
}

output sqlConnectionId string = sqlConnection.id
output loggerWorkflowId string = loggerWorkflow.id
output readerWorkflowId string = readerWorkflow.id

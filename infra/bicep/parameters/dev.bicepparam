using '../main.bicep'

param location = 'canadacentral'
param resourceGroupName = 'rg-charm-dev'
param environment = 'dev'

param aiServicesAccountName = 'ai-res-charm-dev'
param foundryProjectName = 'ai-charm-dev'

param sqlServerName = 'sql-charm-dev'
param sqlDatabaseName = 'charm_uc1_db'
param sqlAdminLogin = '<sql-admin-user>'
param sqlAdminPassword = '<sql-admin-password>'

param keyVaultName = 'kv-charm-dev'
param logicAppLoggerName = 'la-charm-logger-dev'
param logicAppReaderName = 'la-charm-reader-dev'
param sqlApiConnectionName = 'sql'

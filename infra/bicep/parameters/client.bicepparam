using '../main.bicep'

param location = '<client-location>'
param resourceGroupName = '<client-resource-group>'
param environment = 'client'

param aiServicesAccountName = '<client-ai-account-name>'
param foundryProjectName = '<client-foundry-project-name>'

param sqlServerName = '<client-sql-server-name>'
param sqlDatabaseName = '<client-sql-database-name>'
param sqlAdminLogin = '<client-sql-admin-user>'
param sqlAdminPassword = '<client-sql-admin-password>'

param keyVaultName = '<client-keyvault-name>'
param logicAppLoggerName = '<client-logicapp-logger-name>'
param logicAppReaderName = '<client-logicapp-reader-name>'
param sqlApiConnectionName = 'sql'

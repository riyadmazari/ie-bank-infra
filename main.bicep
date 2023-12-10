@sys.description('The environment type (nonprod or prod)')
@allowed([
  'nonprod'
  'prod'
])
param environmentType string = 'nonprod'
@sys.description('The PostgreSQL Server name')
@minLength(3)
@maxLength(24)
param postgreSQLServerName string = 'ie-bank-db-server-dev'
@sys.description('The PostgreSQL Database name')
@minLength(3)
@maxLength(24)
param postgreSQLDatabaseName string = 'ie-bank-db'
@sys.description('The App Service Plan name')
@minLength(3)
@maxLength(24)
param appServicePlanName string = 'ie-bank-app-sp-dev'
@sys.description('The Web App name (frontend)')
@minLength(3)
@maxLength(24)
param appServiceAppName string = 'ie-bank-dev'
@sys.description('The API App name (backend)')
@minLength(3)
@maxLength(24)
param appServiceAPIAppName string = 'ie-bank-api-dev'
@sys.description('The name of the Azure Monitor Workspace')
param azureMonitorName string
@sys.description('The name of the Application Insights')
param appInsightsName string
@sys.description('The Azure location where the resources will be deployed')
param location string = resourceGroup().location
@sys.description('The value for the environment variable ENV')
param appServiceAPIEnvVarENV string
@sys.description('The value for the environment variable DBHOST')
param appServiceAPIEnvVarDBHOST string
@sys.description('The value for the environment variable DBNAME')
param appServiceAPIEnvVarDBNAME string
@sys.description('The value for the environment variable DBPASS')
@secure()
param appServiceAPIEnvVarDBPASS string
@sys.description('The value for the environment variable DBUSER')
param appServiceAPIDBHostDBUSER string
@sys.description('The value for the environment variable FLASK_APP')
param appServiceAPIDBHostFLASK_APP string
@sys.description('The value for the environment variable FLASK_DEBUG')
param appServiceAPIDBHostFLASK_DEBUG string
param containerRegistryName string
param containerRegistryImageName string
param containerRegistryImageVersion string
// param containerRegistryUserName string
// @secure()
// param containerRegistryPassword string
//param webAppName string
param keyVaultName string
@sys.description('The name of the keyvault where secrets are stored')

param keyVaultSecretNameACRUsername string = 'acr-username'
@sys.description('The name of the key vault secret for the ACR username')

param keyVaultSecretNameACRPassword1 string = 'acr-password1'
@sys.description('The name of the key vault secret for the first ACR password')

param keyVaultSecretNameACRPassword2 string = 'acr-password2'
@sys.description('The name of the key vault secret for the second ACR password')



resource postgresSQLServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: postgreSQLServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: 'iebankdbadmin'
    administratorLoginPassword: 'IE.Bank.DB.Admin.Pa$$'
    createMode: 'Default'
    highAvailability: {
      mode: 'Disabled'
      standbyAvailabilityZone: ''
    }
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    version: '15'
  }

  resource postgresSQLServerFirewallRules 'firewallRules@2022-12-01' = {
    name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
    properties: {
      endIpAddress: '0.0.0.0'
      startIpAddress: '0.0.0.0'
    }
  }
}

resource postgresSQLDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  name: postgreSQLDatabaseName
  parent: postgresSQLServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}
// containerRegistry deployment
module containerRegistry 'modules/container-registry/registry/main.bicep' = { 
  dependsOn: [
    keyVault
  ]
  name: '${uniqueString(deployment().name)}${containerRegistryName}'
  params: {
    name: containerRegistryName
    location: location
    acrAdminUserEnabled: true
    adminCredentialsKeyVaultResourceId: resourceId('Microsoft.KeyVault/vaults', keyVaultName)
    adminCredentialsKeyVaultSecretUserName: keyVaultSecretNameACRUsername
    adminCredentialsKeyVaultSecretUserPassword1: keyVaultSecretNameACRPassword1
    adminCredentialsKeyVaultSecretUserPassword2: keyVaultSecretNameACRPassword2
  }
}

module appService 'modules/app-service.bicep' = {
  name: '${uniqueString(deployment().name)}appService'
  params: {
    location: location
    environmentType: environmentType
    appServiceAppName: appServiceAppName
    appServiceAPIAppName: appServiceAPIAppName
    appServicePlanName: appServicePlanName
    appServiceAPIDBHostDBUSER: appServiceAPIDBHostDBUSER
    appServiceAPIDBHostFLASK_APP: appServiceAPIDBHostFLASK_APP
    appServiceAPIDBHostFLASK_DEBUG: appServiceAPIDBHostFLASK_DEBUG
    appServiceAPIEnvVarDBHOST: appServiceAPIEnvVarDBHOST
    appServiceAPIEnvVarDBNAME: appServiceAPIEnvVarDBNAME
    appServiceAPIEnvVarDBPASS: appServiceAPIEnvVarDBPASS
    appServiceAPIEnvVarENV: appServiceAPIEnvVarENV
    containerRegistryImageName: containerRegistryImageName
    containerRegistryImageVersion: containerRegistryImageVersion
    containerRegistryName: containerRegistryName
    keyVaultName: keyVaultName
    dummyOutput: containerRegistry.outputs.name
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
  }
  dependsOn: [
    postgresSQLDatabase
  ]
}

resource azureMonitor 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: azureMonitorName
  location: location
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: resourceId('Microsoft.OperationalInsights/workspaces', azureMonitorName)
  }
}

output appServiceAppHostName string = appService.outputs.appServiceAppHostName

// Azure Web App for Linux containers module
// module website 'modules/web/site/main.bicep' = {
//   dependsOn: [
//     appService
//   ]
//   name: '${uniqueString(deployment().name)}site'
//   params: {
//     name: webAppName
//     location: location
//     serverFarmResourceId: resourceId('Microsoft.Web/serverfarms', appServicePlanName)
//     siteConfig: {
//       linuxFxVersion: 'DOCKER|${containerRegistryName}.azurecr.io/${containerRegistryImageName}:${containerRegistryImageVersion}'
//       appCommandLine: ''
//     }
//     kind: 'app'
//     appSettingsKeyValuePairs: {
//       WEBSITES_ENABLE_APP_SERVICE_STORAGE: false
//       DOCKER_REGISTRY_SERVER_URL: 'https://${containerRegistryName}.azurecr.io'
//       DOCKER_REGISTRY_SERVER_USERNAME: containerRegistryUserName
//       DOCKER_REGISTRY_SERVER_PASSWORD: containerRegistryPassword
//     }
//   }
// }


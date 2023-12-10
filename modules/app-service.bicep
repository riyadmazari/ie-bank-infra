param location string = resourceGroup().location
param appServicePlanName string
param appServiceAppName string
param appServiceAPIAppName string
param appServiceAPIEnvVarENV string
param appServiceAPIEnvVarDBHOST string
param appServiceAPIEnvVarDBNAME string
param appInsightsInstrumentationKey string
@secure()
param appServiceAPIEnvVarDBPASS string
param appServiceAPIDBHostDBUSER string
param appServiceAPIDBHostFLASK_APP string
param appServiceAPIDBHostFLASK_DEBUG string
param containerRegistryName string
param containerRegistryImageName string
param containerRegistryImageVersion string
@allowed([
  'nonprod'
  'prod'
  'uat'
])
param environmentType string
param keyVaultName string
param dummyOutput string
param keyVaultSecretNameACRUsername string = 'acr-username'
param keyVaultSecretNameACRPassword1 string = 'acr-password1'

var appServicePlanSkuName = (environmentType == 'prod') ? 'B1' : 'F1'

resource appServicePlan 'Microsoft.Web/serverFarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSkuName
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// resource appServiceAPIApp 'Microsoft.Web/sites@2022-03-01' = {
//   name: appServiceAPIAppName
//   location: location
//   properties: {
//     serverFarmId: appServicePlan.id
//     httpsOnly: true
//     siteConfig: {
//       linuxFxVersion: 'DOCKER|${containerRegistryName}.azurecr.io/${containerRegistryImageName}:${containerRegistryImageVersion}'
//       alwaysOn: false
//       ftpsState: 'FtpsOnly'
//       appSettings: [
//         {
//           name: 'ENV'
//           value: appServiceAPIEnvVarENV
//         }
//         {
//           name: 'DBHOST'
//           value: appServiceAPIEnvVarDBHOST
//         }
//         {
//           name: 'DBNAME'
//           value: appServiceAPIEnvVarDBNAME
//         }
//         {
//           name: 'DBPASS'
//           value: appServiceAPIEnvVarDBPASS
//         }
//         {
//           name: 'DBUSER'
//           value: appServiceAPIDBHostDBUSER
//         }
//         {
//           name: 'FLASK_APP'
//           value: appServiceAPIDBHostFLASK_APP
//         }
//         {
//           name: 'FLASK_DEBUG'
//           value: appServiceAPIDBHostFLASK_DEBUG
//         }
//         {
//           name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
//           value: 'true'
//         }
//       ]
//     }
//   }
// }

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

module website '../modules/web/site/main.bicep' = {
  dependsOn: [
    appServicePlan
  ]
  name: '${uniqueString(deployment().name)}-app'
  params: {
    name: appServiceAPIAppName
    location: location
    kind: 'app'
    serverFarmResourceId: resourceId('Microsoft.Web/serverfarms', appServicePlanName)
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistryName}.azurecr.io/${containerRegistryImageName}:${containerRegistryImageVersion}'
      appCommandLine: ''
    }
    appSettingsKeyValuePairs: {
      WEBSITES_ENABLE_APP_SERVICE_STORAGE: false
      DUMMY: dummyOutput
      ENV: appServiceAPIEnvVarENV
      DBHOST: appServiceAPIEnvVarDBHOST
      DBNAME: appServiceAPIEnvVarDBNAME
      DBPASS: appServiceAPIEnvVarDBPASS
      DBUSER: appServiceAPIDBHostDBUSER
      FLASK_APP: appServiceAPIDBHostFLASK_APP
      FLASK_DEBUG: appServiceAPIDBHostFLASK_DEBUG
      SCM_DO_BUILD_DURING_DEPLOYMENT: true
      APPINSIGHTS_INSTRUMENTATIONKEY: appInsightsInstrumentationKey
    }
    dockerRegistryServerUrl: 'https://${containerRegistryName}.azurecr.io'
    dockerRegistryServerUsername: keyVault.getSecret(keyVaultSecretNameACRUsername)
    dockerRegistryServerPassword: keyVault.getSecret(keyVaultSecretNameACRPassword1)
  }
}


// resource appServiceApp 'Microsoft.Web/sites@2022-03-01' = {
//   name: appServiceAppName
//   location: location
//   properties: {
//     serverFarmId: appServicePlan.id
//     httpsOnly: true
//     siteConfig: {
//       linuxFxVersion: 'NODE|18-lts'
//       alwaysOn: false
//       ftpsState: 'FtpsOnly'
//       appCommandLine: 'pm2 serve /home/site/wwwroot --spa --no-daemon'
//       appSettings: []
//     }
//   }
// }

module staticSite '../modules/web/static-site/main.bicep' = {
  name: '${uniqueString(deployment().name, location)}-static-site'
  params: {
    name: appServiceAppName
    sku: 'Standard'
  }
}

output appServiceAppHostName string = staticSite.outputs.defaultHostname

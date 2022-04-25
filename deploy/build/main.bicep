// set the target scope for this file
targetScope = 'subscription'

@minLength(3)
@maxLength(11)
param namePrefix string
param location string = deployment().location
param policySendListenName string
param policySendOnlyName string
param administratorLogin string
param administratorLoginPassword string

var resourceGroupName = '${namePrefix}-rg'

// Create a Resource Group
resource newRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// Create a Storage Account
module stgModule '../build/storage.bicep' = {
  name: 'storageDeploy'
  scope: newRG
  params: {
    namePrefix: namePrefix
    location: location
  }
}

// Create Application Insights & Log Analytics Workspace
module appInsightsModule '../build/appinsights_loganalytics.bicep' = {
  name: 'appInsightsDeploy'
  scope: newRG
  params: {
    namePrefix: namePrefix
    location: location
  }
}

// Create API Management instance
module apimModule '../build/apim.bicep' = {
  name: 'apimDeploy'
  scope: newRG
  params: {
    namePrefix: namePrefix
    publisherEmail: 'me@example.com'
    publisherName: 'Me Company Ltd.'
    sku: 'Developer'
    location: location
    appInsightsName: appInsightsModule.outputs.appInsightsName
    appInsightsInstrKey: appInsightsModule.outputs.appInsightsInstrKey
  }
  dependsOn:[
    appInsightsModule
  ]
}

// Create Logic Apps (Standard)
module logicAppModule '../build/logicapp_asp.bicep' = {
  name: 'logicAppDeploy'
  scope: newRG
  params: {
    namePrefix: namePrefix
    location: location
    appInsightsInstrKey: appInsightsModule.outputs.appInsightsInstrKey
    appInsightsEndpoint: appInsightsModule.outputs.appInsightsEndpoint
    storageConnectionString: stgModule.outputs.storageConnectionString
  }
  dependsOn:[
    appInsightsModule
    stgModule
  ]
}

// Create Service Bus
module serviceBusModule '../build/servicebus.bicep' = {
  name: 'serviceBusDeploy'
  scope: newRG
  params: {
    namePrefix: namePrefix
    location: location
    policySendListenName: policySendListenName
    policySendOnlyName: policySendOnlyName
  }
}

// Create Azure SQL
module sqlModule '../build/sql.bicep' = {
  name: 'sqlDeploy'
  scope: newRG
  params: {
    namePrefix: namePrefix
    location: location
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
  }
}

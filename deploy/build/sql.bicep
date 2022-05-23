@minLength(3)
@maxLength(11)
param namePrefix string
param location string = resourceGroup().location
param administratorLogin string
@secure()
param administratorLoginPassword string

var serverName = 'sql-${namePrefix}${uniqueString(resourceGroup().id)}-svr'
var sqlDBName = 'sql-${namePrefix}-db'

resource server 'Microsoft.Sql/servers@2019-06-01-preview' = {
  name: serverName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2020-08-01-preview' = {
  name: '${server.name}/${sqlDBName}'
  location: location
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    capacity: 2
  }
}

resource symbolicname 'Microsoft.Sql/servers/firewallRules@2021-11-01-preview' = {
  name: 'AllowAzureServices'
  parent: server
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

output serverName string = server.name
output sqlDBName string = sqlDB.name

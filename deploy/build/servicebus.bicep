@minLength(3)
@maxLength(11)
param namePrefix string
param location string = resourceGroup().location

var uniqueServiceBusNamespaceName = '${namePrefix}${uniqueString(resourceGroup().id)}-ns'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: uniqueServiceBusNamespaceName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {}
}

output serviceBusNamespaceName string = serviceBusNamespace.name

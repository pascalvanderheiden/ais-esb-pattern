param ($subscriptionId, $deploymentNameBuild, $deploymentNameRelease, $namePrefix, $administratorLogin, $administratorLoginPassword)

Write-Host "Setting the paramaters:"
$location = "West Europe"
$resourceGroup = "$namePrefix-rg"
$buildBicepPath = ".\deploy\build\main.bicep"
$releaseSBBicepPath = ".\deploy\release\servicebus_topic_sub.bicep"
$releaseAPIMBicepPath = ".\deploy\release\apim_apis.bicep"
$releaseSqlScriptPath = ".\deploy\release\sql_table.sql"
$deploymentNameSBRelease = "$namePrefix-sb-release"
$deploymentNameAPIMRelease = "$namePrefix-apim-release"
$sqlDBName = "sql-$namePrefix-db"
$workflowGetName = "ais-esb-get-wf"
$workflowPathGet = ".\$workflowGetName"
$workflowPostName = "ais-esb-post-wf"
$workflowPathPost = ".\$workflowPostName"
$workflowPathProcessSubOds = ".\ais-esb-process-sub-ods-wf"
$destinationPath = ".\deploy\release\ais-esb-wf-release.zip"
$policySendListenName = "SendListen"
$policySendOnlyName = "SendOnly"
$serviceBusTopicName = "customer-topic"
$serviceBusSubODSName = "customer-ods-sub"
$serviceBusSubUpdName = "customer-upd-sub"
$serviceBusSubscriptionPath = "/$serviceBusTopicName/subscriptions/$serviceBusSubUpdName/messages/head"

Write-Host "Subscription id: "$subscriptionId
Write-Host "Deployment Name Build: "$deploymentNameBuild
Write-Host "Deployment Name Release Service Bus: "$deploymentNameSBRelease
Write-Host "Deployment Name Release API Management: "$deploymentNameAPIMRelease
Write-Host "Resource Group: "$resourceGroup
Write-Host "Location: "$location
Write-Host "Build by Bicep File: "$buildBicepPath
Write-Host "Release API's by Bicep File: "$releaseAPIMBicepPath
Write-Host "Release Topics & Subscribers by Bicep File: "$releaseSBBicepPath
Write-Host "Release SQL by script File: "$releaseSqlScriptPath
Write-Host "SQL DB Name: "$sqlDBName

Write-Host "Login to Azure:"
Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

Write-Host "Build"
Write-Host "Deploy Infrastructure as Code:"
New-AzSubscriptionDeployment -name $deploymentNameBuild -namePrefix $namePrefix -location $location -policySendListenName $policySendListenName -policySendOnlyName $policySendOnlyName -administratorLogin $administratorLogin -administratorLoginPassword $administratorLoginPassword -TemplateFile $buildBicepPath

Write-Host "Release"
Write-Host "Retrieve API Management Instance Name:"
$apimName = az apim list --resource-group $resourceGroup --subscription $subscriptionId --query "[].{Name:name}" -o tsv
Write-Host "API Management Instance:"$apimName

Write-Host "Release Service Bus Topic and Subscribers:"
$serviceBusNamespaceName = az servicebus namespace list --resource-group $resourceGroup --subscription $subscriptionId --query "[].{Name:name}" -o tsv
Write-Host "Service Bus Namespace:"$serviceBusNamespaceName
New-AzResourceGroupDeployment -Name $deploymentNameSBRelease -ResourceGroupName $resourceGroup -serviceBusNamespaceName $serviceBusNamespaceName -serviceBusTopicName $serviceBusTopicName -serviceBusSubODSName $serviceBusSubODSName -serviceBusSubUpdName $serviceBusSubUpdName -TemplateFile $releaseSBBicepPath

Write-Host "Retrieve Service Bus Access Policy Key:"
$policySendListenKey = az servicebus namespace authorization-rule keys list --resource-group $resourceGroup --namespace-name $serviceBusNamespaceName --name $policySendListenName --query "{primaryKey:primaryKey}" -o tsv

Write-Host "Generate Service Bus SAS Key and store in API Management as Named Value:"
$serviceBusSubUpdUri = "https://$serviceBusNamespaceName.servicebus.windows.net/${serviceBusTopicName}/subscriptions/${serviceBusSubUpdName}"
.\deploy\release\get-saskey-from-service-bus.ps1 -serviceBusUri $serviceBusSubUpdUri -accessPolicyName $policySendListenName -accessPolicyKey $policySendListenKey -apimName $apimName -resourceGroup $resourceGroup -apimNamedValueSig $serviceBusTopicName

Write-Host "Create SQL Tables:"
$serverName = az sql server list --resource-group $resourceGroup --subscription $subscriptionId --query "[].{Name:name}" -o tsv
$serverFQDName = az sql server list --resource-group $resourceGroup --subscription $subscriptionId --query "[].{fullyQualifiedDomainName:fullyQualifiedDomainName}" -o tsv
Write-Host "SQL Server: "$serverFQDName
$agentIP = (New-Object net.webclient).downloadstring("https://api.ipify.org")
az sql server firewall-rule create -g $resourceGroup -s $serverName -n "AllowMyIp" --start-ip-address $agentIP --end-ip-address $agentIP
az sql server firewall-rule create -g $resourceGroup -s $serverName -n "AllowAzureServices" --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
Invoke-Sqlcmd -InputFile $releaseSqlScriptPath -ServerInstance $serverFQDName -Database $sqlDBName -Username $administratorLogin -Password $administratorLoginPassword

Write-Host "Release Logic App Workflows:"
$logicAppName = az logic app list --resource-group $resourceGroup --subscription $subscriptionId --query "[].{Name:name}" -o tsv
.\deploy\release\logicapps_wf.ps1 -subscriptionId $subscriptionId -resourceGroup $resourceGroup -logicAppName $logicAppName -workflowPathGet $workflowPathGet -workflowPathPost $workflowPathPost -workflowPathProcessSubOds $workflowPathProcessSubOds -destinationPath $destinationPath

Write-Host "Update connection string Service Bus & SQL in AppSettings Logic App:"
#hier moet nog iets, service bus connection string ophalen voor SendListen en SQL connections string.
#deze moeten gevuld worden met een update:
#sql_connectionString = Server=sqlvm01.aisase-ase.appserviceenvironment.net,1433;database=TestDB;UID=sa;PWD=Integration123
#serviceBus_connectionString = endpoint uit portal (AZ script voor vinden, zou moet bicep kunnen) Endpoint=sb://aisshared-ns.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=El7CUbmf3uVvLFmmqNXzVjW9QG8NPw6V7GEkuRZZv90=


Write-Host "Retrieve SAS Keys and store in API Management as Named Value:"
.\deploy\release\get-saskey-from-logic-app.ps1 -subscriptionId $subscriptionId -resourceGroup $resourceGroup -logicAppName $logicAppName -workflowName $workflowGetName -apimName $apimName -apimNamedValueSig $workflowGetName
.\deploy\release\get-saskey-from-logic-app.ps1 -subscriptionId $subscriptionId -resourceGroup $resourceGroup -logicAppName $logicAppName -workflowName $workflowPostName -apimName $apimName -apimNamedValueSig $workflowPostName

Write-Host "Release API definition to API Management:"
New-AzResourceGroupDeployment -Name $deploymentNameAPIMRelease -ResourceGroupName $resourceGroup -apimName $apimName -appInsightsName $appInsightsName -logicAppName $logicAppName -serviceBusName $serviceBusName -serviceBusSubscriptionPath $serviceBusSubscriptionPath -serviceBusSendListenSigNamedValue $serviceBusTopicName -workflowGetName $workflowGetName -workflowGetSigNamedValue $workflowGetName -workflowPostName $workflowPostName -workflowPostSigNamedValue $workflowPostName -TemplateFile $releaseAPIMBicepPath
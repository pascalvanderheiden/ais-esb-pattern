param ($subscriptionId, $resourceGroup, $logicAppName, $workflowPathGet, $workflowPathPost, $workflowPathProcessSubOds, $destinationPath)

Write-Host "Setting the paramaters:"
Write-Host "Subscription id: "$subscriptionId
Write-Host "Resource Group: "$resourceGroup
Write-Host "Logic App Name: "$logicAppName
Write-Host "Workflow Path Get: "$workflowPathGet
Write-Host "Workflow Path Post: "$workflowPathPost
Write-Host "Workflow Path Process updates to ODS: "$workflowPathProcessSubOds
Write-Host "Destination Path ZIP Deployment: "$destinationPath

Write-Host "Release Workflows to Logic App:"
$compress = @{
    Path = $workflowPathGet, $workflowPathPost, $workflowPathProcessSubOds, ".\host.json", ".\connections.json"
    CompressionLevel = "Fastest"
    DestinationPath = $destinationPath
}
Compress-Archive @compress

az logicapp deployment source config-zip --name $logicAppName --resourcegroup $resourceGroup --subscription $subscriptionId --src $destinationPath
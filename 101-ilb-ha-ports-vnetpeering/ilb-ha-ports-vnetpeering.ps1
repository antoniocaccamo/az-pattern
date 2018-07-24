################# Input parameters #################
$subscriptionName = "SET_HERE_THE_NAME_OF_YOUR_AZURE_SUBSCRIPTION"    
$location         = "eastus"
$destResourceGrp  = "rg-ha-ports-02"
$resourceGrpDeployment = "vnet-ilb"
$armTemplateFile       = "ilb-ha-ports-vnetpeering.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzureRmSubscription -SubscriptionName $subscriptionName
Select-AzureRmSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzureRmResourceGroup -Name $destResourceGrp -Location $location
write-host $templateFile
New-AzureRmResourceGroupDeployment  -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp -TemplateFile $templateFile -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()
#Login to Azure and resource manager
Add-AzureAccount
Login-AzureRmAccount

#Just in case you have multiple subscriptions check which one you're working in
Get-AzureSubscription

#If you need to select your test subscription use:
#Set-AzureSubscription -SubscriptionName <name>

#First the resource group
$RGName = "security-rg"
$Location = "North Europe"

#Create an encrypted storage account for Azure Security Center
#Currently encryption is only available for Azure Blob
New-AzureRmStorageAccount -ResourceGroupName $RGName -AccountName "securitylogstr" -Location $Location -Type "Standard_LRS" -EnableEncryptionService Blob

#https://docs.microsoft.com/en-us/azure/storage/storage-security-guide#encryption-at-rest
#https://docs.microsoft.com/en-us/azure/security-center/security-center-intro
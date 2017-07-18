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

#Obviously populate with your own name and password details rather than the example below
New-AzureRmADApplication -DisplayName "test-aad-app" -HomePage "http://testapp.com" `
    -IdentifierUris "http://testapp.com" -ReplyUrls "http://testapp.com" -Password "Password123"


#Setup my variables
#Most of the values came from the output of the Microsoft Encryption script
#Substitute with your own values output from the MS script
$vmName = "mgmt-vm"
$resourceGroupName = "hub-rg"
$aadClientID = "xxxxxxxxxxxxxxxxxxxx"
$aadClientSecret = "xxxxxxxxxxxxxxxxxxxxxxx"
$diskEncryptionKeyVaultUrl = "https://lab-vault.vault.azure.net/"
$keyVaultResourceId = "/subscriptions/xxxxxxxxxxxxxxxxxxx/resourceGroups/hub-rg/providers/Microsoft.KeyVault/vaults/lab-vault"

#Now use those variables in a one-liner to encrypt the mgmt-vm
Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $resourceGroupName -VMName $vmName `
    -AadClientID $aadClientID -AadClientSecret $aadClientSecret `
    -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $keyVaultResourceId

#Bash commands to install the Azure VM agent on CentOS
#sudo yum install python-pyasn1 WALinuxAgent
#sudo systemctl enable waagent

#Setup my variables
#Most of the values came from the output of the Microsoft Encryption script
$vmName = "web-vm"
$resourceGroupName = "dmz-rg"
$aadClientID = "xxxxxxxxxxxxxxxxxxxx"
$aadClientSecret = "xxxxxxxxxxxxxxxxxxxxxxx"
$diskEncryptionKeyVaultUrl = "https://lab-vault.vault.azure.net/"
$keyVaultResourceId = "/subscriptions/xxxxxxxxxxxxxxxxxxx/resourceGroups/hub-rg/providers/Microsoft.KeyVault/vaults/lab-vault"

#Now use those variables to encrypt web-vm's data disk
Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $resourceGroupName -VMName $vmName `
    -VolumeType Data `
    -AadClientID $aadClientID -AadClientSecret $aadClientSecret `
    -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $keyVaultResourceId

#ad-vm
$vmName = "ad-vm"
$resourceGroupName = "internal-rg"
$aadClientID = "xxxxxxxxxxxxxxxxxxxx"
$aadClientSecret = "xxxxxxxxxxxxxxxxxxxxxxx"
$diskEncryptionKeyVaultUrl = "https://lab-vault.vault.azure.net/"
$keyVaultResourceId = "/subscriptions/xxxxxxxxxxxxxxxxxxx/resourceGroups/hub-rg/providers/Microsoft.KeyVault/vaults/lab-vault"

#Now use those variables to encrypt the disks
Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $resourceGroupName -VMName $vmName `
    -AadClientID $aadClientID -AadClientSecret $aadClientSecret `
    -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $keyVaultResourceId

#aadconnect-vm
$vmName = "aadconnect-vm"
$resourceGroupName = "internal-rg"
$aadClientID = "xxxxxxxxxxxxxxxxxxxx"
$aadClientSecret = "xxxxxxxxxxxxxxxxxxxxxxx"
$diskEncryptionKeyVaultUrl = "https://lab-vault.vault.azure.net/"
$keyVaultResourceId = "/subscriptions/xxxxxxxxxxxxxxxxxxx/resourceGroups/hub-rg/providers/Microsoft.KeyVault/vaults/lab-vault"

#Now use those variables to encrypt the disks
Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $resourceGroupName -VMName $vmName `
    -AadClientID $aadClientID -AadClientSecret $aadClientSecret `
    -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $keyVaultResourceId
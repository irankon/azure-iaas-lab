#Create the DMZ base build

#Login to Azure and resource manager
Add-AzureAccount
Login-AzureRmAccount

#Just in case you have multiple subscriptions check which one you're working in
Get-AzureSubscription

#If you need to select your test subscription use:
#Set-AzureSubscription -SubscriptionName <name>

#First the resource group
$RGName = "dmz-rg"
$Location = "North Europe"
New-AzureRmResourceGroup -Name $RGName -Location $Location

#Now the DMZ network
New-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name dmz-vnet `
    -AddressPrefix 192.168.0.0/16 -Location $Location

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name dmz-vnet

Add-AzureRmVirtualNetworkSubnetConfig -Name web-subnet `
    -VirtualNetwork $vnet -AddressPrefix 192.168.1.0/24

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

#Create the storage account
New-AzureRmStorageAccount -ResourceGroupName $RGName -AccountName "dmzvmstr" -Location $Location -Type "Standard_LRS"

#First setup default credentials to use in provisioning by retrieving and decrypting our Key Vault password
$Username = "adminuser"
$SecurePwd = Get-AzureKeyVaultSecret -VaultName 'lab-vault' -Name 'ProvisionPassword'
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePwd.SecretValue

#Setup Centos webserver
$VMName = "web-vm"
$VMSize = "Standard_A1"
$OSDiskName = $VMName + "OSDisk"
$DataDiskName = $VMName + "DataDisk"
$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName  $RGName -Name dmzvmstr

#Webserver VM Network
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name dmz-vnet
$NIC1 = New-AzureRmNetworkInterface -Name "web-vm-eth0" -ResourceGroupName $RGName -Location $Location -SubnetId $vnet.Subnets[0].Id -PrivateIpAddress 192.168.1.4
Set-AzureRmNetworkInterface -NetworkInterface $NIC1

#Setup our webserver VM object
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -ComputerName $VMName -Linux -Credential $Credential
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName "OpenLogic" -Offer "CentOS" -Skus "7.1" -Version "latest"
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC1.Id
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage
$DataDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $DataDiskName + ".vhd"
$VirtualMachine = Add-AzureRmVMDataDisk -VM $VirtualMachine -Name $DataDiskName -Caching 'ReadOnly' -DiskSizeInGB 10 -Lun 0 -VhdUri $DataDiskUri -CreateOption Empty


#Create the Webserver VM
New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $VirtualMachine
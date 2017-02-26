#Create the internal base build

#Login to Azure and resource manager
Add-AzureAccount
Login-AzureRmAccount

#Just in case you have multiple subscriptions check which one you're working in
Get-AzureSubscription

#If you need to select your test subscription use:
#Set-AzureSubscription -SubscriptionName <name>

#First the resource group
$RGName = "internal-rg"
$Location = "North Europe"
New-AzureRmResourceGroup -Name $RGName -Location $Location

#Now the internal network
New-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name internal-vnet `
    -AddressPrefix 172.1.0.0/16 -Location $Location

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name internal-vnet

Add-AzureRmVirtualNetworkSubnetConfig -Name ad-subnet `
    -VirtualNetwork $vnet -AddressPrefix 172.1.1.0/24

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

#Create the storage account
New-AzureRmStorageAccount -ResourceGroupName $RGName -AccountName "internalvmstr" -Location $Location -Type "Standard_LRS"

#Setup a Windows AD VM
$VMName = "ad-vm"
$VMSize = "Standard_A1"
$OSDiskName = $VMName + "OSDisk"
$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName  $RGName -Name internalvmstr
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name internal-vnet

#AD VM Network Config
$NIC1 = New-AzureRmNetworkInterface -Name "ad-vm-eth0" -ResourceGroupName $RGName -Location $Location -SubnetId $vnet.Subnets[0].Id -PrivateIpAddress 172.1.1.4
Set-AzureRmNetworkInterface -NetworkInterface $NIC1

#First setup default credentials to use in provisioning by retrieving and decrypting our Key Vault password
$Username = "adminuser"
$SecurePwd = Get-AzureKeyVaultSecret -VaultName 'lab-vault' -Name 'ProvisionPassword'
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePwd.SecretValue

#Setup AD VM object config
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -ComputerName $VMName -Windows -Credential $Credential
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2012-R2-Datacenter" -Version "latest"
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC1.Id
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

#Create the AD VM
New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $VirtualMachine

#Right, let's rinse and repeat to build up an AAD Connect box

#Setup a Windows AAD Connect VM
$VMName = "aadconnect-vm"
$VMSize = "Standard_A1"
$OSDiskName = $VMName + "OSDisk"

#AAD Connect VM Network Config
$NIC1 = New-AzureRmNetworkInterface -Name "aadconnect-vm-eth0" -ResourceGroupName $RGName -Location $Location -SubnetId $vnet.Subnets[0].Id -PrivateIpAddress 172.1.1.5
Set-AzureRmNetworkInterface -NetworkInterface $NIC1

#Setup AAD Connect VM object config
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -ComputerName $VMName -Windows -Credential $Credential
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2012-R2-Datacenter" -Version "latest"
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC1.Id
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

#Create the AAD Connect VM
New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $VirtualMachine
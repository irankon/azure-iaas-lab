#Create the Security group base build

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
New-AzureRmResourceGroup -Name $RGName -Location $Location

#Now the Security network
New-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name security-vnet `
    -AddressPrefix 10.2.0.0/16 -Location $Location

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name security-vnet

Add-AzureRmVirtualNetworkSubnetConfig -Name firewall-subnet `
    -VirtualNetwork $vnet -AddressPrefix 10.2.1.0/28

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

#Now setup peering to our other VNETs

#First get my VNETs
$vnet1 = Get-AzureRmVirtualNetwork -ResourceGroupName dmz-rg -Name dmz-vnet
$vnet2 = Get-AzureRmVirtualNetwork -ResourceGroupName hub-rg -Name hub-vnet
$vnet3 = Get-AzureRmVirtualNetwork -ResourceGroupName internal-rg -Name internal-vnet
$vnet4 = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name $vnet.Name


#Setup links between the vnets
#First between the Security and DMZ
Add-AzureRmVirtualNetworkPeering -name DMZToSecurity-Peer -VirtualNetwork $vnet1 -RemoteVirtualNetworkId $vnet4.id
Add-AzureRmVirtualNetworkPeering -name SecurityToDMZ-Peer -VirtualNetwork $vnet4 -RemoteVirtualNetworkId $vnet1.id

#Then between the Hub and Security vnets
Add-AzureRmVirtualNetworkPeering -name SecurityToHub-Peer -VirtualNetwork $vnet4 -RemoteVirtualNetworkId $vnet2.id
Add-AzureRmVirtualNetworkPeering -name HubToSecurity-Peer -VirtualNetwork $vnet2 -RemoteVirtualNetworkId $vnet4.id

#Then, finally, between the Internal and Security vnets
Add-AzureRmVirtualNetworkPeering -name SecurityToInternal-Peer -VirtualNetwork $vnet4 -RemoteVirtualNetworkId $vnet3.id
Add-AzureRmVirtualNetworkPeering -name InternalToSecurity-Peer -VirtualNetwork $vnet3 -RemoteVirtualNetworkId $vnet4.id

#Amend with the commands below (in this case allowing Gateway transit)
# These settings are correct but you need a site-to-site vpn and to specify the peer network as a 'local network'
# Perhaps setup site-to-site vpn using a server 2012 box?  Need a public IP?

$DMZToSecurityLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName dmz-vnet -ResourceGroupName dmz-rg -Name DMZToSecurity-Peer
$DMZToSecurityLink.UseRemoteGateways = $true

$SecurityToDMZLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName security-vnet -ResourceGroupName $RGName -Name SecurityToDMZ-Peer
$SecurityToDMZLink.UseRemoteGateways = $true

$HubToSecurityLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName hub-vnet -ResourceGroupName hub-rg -Name HubToSecurity-Peer
$HubToSecurityLink.UseRemoteGateways = $true

$SecurityToHubLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName security-vnet -ResourceGroupName $RGName -Name SecurityToHub-Peer
$SecurityToHubLink.UseRemoteGateways = $true

$InternalToSecurityLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName internal-vnet -ResourceGroupName internal-rg -Name InternalToSecurity-Peer
$InternalToSecurityLink.UseRemoteGateways = $true

$SecurityToInternalLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName security-vnet -ResourceGroupName $RGName -Name SecurityToInternal-Peer
$SecurityToInternalLink.UseRemoteGateways = $true

#Create the storage account
New-AzureRmStorageAccount -ResourceGroupName $RGName -AccountName "securityvmstr" -Location $Location -Type "Standard_LRS"

#First setup default credentials to use in provisioning by retrieving and decrypting our Key Vault password
$Username = "adminuser"
$SecurePwd = Get-AzureKeyVaultSecret -VaultName 'lab-vault' -Name 'ProvisionPassword'
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePwd.SecretValue

#Build Ubuntu firewall VM

#Base VM variables
$VMName = "firewall-vm"
$VMSize = "Standard_D2"
$OSDiskName = $VMName + "OSDisk"
$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName  $RGName -Name securityvmstr
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name security-vnet

#VM Network Interface Details
$NIC1 = New-AzureRmNetworkInterface -Name "firewall-vm-eth0" -ResourceGroupName $RGName -Location $Location -SubnetId $vnet.Subnets[0].Id -PrivateIpAddress 10.2.1.4
$NIC1.EnableIPForwarding = 1
Set-AzureRmNetworkInterface -NetworkInterface $NIC1

$NIC2 = New-AzureRmNetworkInterface -Name "firewall-vm-eth1" -ResourceGroupName $RGName -Location $Location -SubnetId $vnet.Subnets[0].Id  -PrivateIpAddress 10.2.1.5
$NIC2.EnableIPForwarding = 1
Set-AzureRmNetworkInterface -NetworkInterface $NIC2

#Setup the VM object
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -ComputerName $VMName -Linux -Credential $Credential
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName "Canonical" -Offer "UbuntuServer" -Skus "14.04.4-LTS" -Version "latest"
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC1.Id -Primary
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC2.Id
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

# If I could afford ClearOS then I'd need to set a plan as this is a Market Place VM
# Set-AzureRmVMPlan -VM $VirtualMachine -Publisher "clear-linux-project" -Product "clear-linux-os" -Name "basic"

#Create the Firewall VM
New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $VirtualMachine 
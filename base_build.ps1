#Login to Azure and resource manager
Add-AzureAccount
Login-AzureRmAccount

#Just in case you have multiple subscriptions check which one you're working in
Get-AzureSubscription

#If you need to select your test subscription use:
#Set-AzureSubscription -SubscriptionName <name>

#Build up the hub
#First the resource group
$RGName = "hub-rg"
$Location = "North Europe"
New-AzureRmResourceGroup -Name $RGName -Location $Location

#Now the hub network
New-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name hub-vnet `
    -AddressPrefix 10.1.0.0/16 -Location $Location

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name hub-vnet

Add-AzureRmVirtualNetworkSubnetConfig -Name mgmt-subnet `
    -VirtualNetwork $vnet -AddressPrefix 10.1.1.0/24

#Annoyling the gateway subnet has to be called GatewaySubnet, ruining my naming convention!
Add-AzureRmVirtualNetworkSubnetConfig -Name GatewaySubnet `
    -VirtualNetwork $vnet -AddressPrefix 10.1.2.0/28

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

#Create Point-to-Site VPN

#Set basic variables for our gateway
$GWName = "hub-gw"
$GWIPName = "hub-gw-pip"
$GWIPconfName = "hub-gw-conf"
$VPNClientAddressPool = "10.3.1.0/28"

#Get the gateway subnet details.  First need to get the recently set vnet again
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name hub-vnet
$GWsubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet

#Public IP for the gateway
$GWPIP = New-AzureRmPublicIpAddress -Name $GWIPName -ResourceGroupName $RGName -Location $Location -AllocationMethod Dynamic

#Create the gateway config
$GWIPConfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name $GWIPconfName -SubnetId $GWsubnet.Id -PublicIpAddressId $GWPIP.Id

#Finally create the VPN Gateway
#This takes ages to run!
$GW = New-AzureRmVirtualNetworkGateway -Location $Location -Name $GWName -ResourceGroupName $RGName `
-GatewayType Vpn -IpConfigurations $GWIPConfig -VpnType RouteBased `
-EnableBgp $false -GatewaySku Standard

#Now set extra VPN gateway settings
Set-AzureRmVirtualNetworkGatewayVpnClientConfig -VirtualNetworkGateway $GW -VpnClientAddressPool $VPNClientAddressPool

#Create the self-signed root and client cert using the guide below:
# https://azure.microsoft.com/en-gb/documentation/articles/vpn-gateway-certificates-point-to-site/

#Get the cert imported into Azure (substitute your own path/name)
$P2SRootCertName = "AzureLabP2SRootCert.cer"
$FilePathForCert = "C:\SSL\AzureLabP2SRootCert.cer"
$Cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2($FilePathForCert)
$CertBase64 = [system.convert]::ToBase64String($Cert.RawData)
$P2SRootCert = Add-AzureRmVpnClientRootCertificate -VpnClientRootCertificateName $P2SRootCertName -PublicCertData $CertBase64 -VirtualNetworkGatewayName $GW.Name -ResourceGroupName $RGName

#Finally get URL for VPN client
$PackageUrl = Get-AzureRmVpnClientPackage -ResourceGroupName $RGName -VirtualNetworkGatewayName $GW.Name -ProcessorArchitecture Amd64

#Display the URL path and download the .exe from here
$PackageUrl

#Create an Azure Key Vault
New-AzureRmKeyVault -VaultName lab-vault -ResourceGroupName $RGName -Location $Location

#Add a secret (password) to that vault
#The secret (password) has to be in a secure string format so you'll need to covert it first

#Convert to secure string
$Password = ConvertTo-SecureString -String '<your_password>' -AsPlainText -Force

#Add the password as a secret
Set-AzureKeyVaultSecret -VaultName 'lab-vault' -Name 'ProvisionPassword' -SecretValue $Password

#Create a hub storage account which we'll use for VM storage
New-AzureRmStorageAccount -ResourceGroupName $RGName -AccountName "hubvmstr" -Location $Location -Type "Standard_LRS"

#Setup Windows VM

#First setup default credentials to use in provisioning by retrieving and decrypting our Key Vault password
$Username = "adminuser"
$SecurePwd = Get-AzureKeyVaultSecret -VaultName 'lab-vault' -Name 'ProvisionPassword'
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePwd.SecretValue

#Define Management VM basics
$VMName = "mgmt-vm"
$VMSize = "Standard_A1"
$OSDiskName = $VMName + "OSDisk"
$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $RGName -Name hubvmstr
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName -Name hub-vnet

#Define Management VM network details
#This will statically assign an IP to the VM.  10.1.1.4 is the next IP available as .0-3 are reserved by Azure
$NIC1 = New-AzureRmNetworkInterface -Name "mgmt-vm-eth0" -ResourceGroupName $RGName -Location $Location -SubnetId $vnet.Subnets[0].Id -PrivateIpAddress 10.1.1.4
Set-AzureRmNetworkInterface -NetworkInterface $NIC1

#Define the Management VM config
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -ComputerName $VMName -Windows -Credential $Credential
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2016-Datacenter" -Version "latest"
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC1.Id
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

#Create the Management VM
New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $VirtualMachine
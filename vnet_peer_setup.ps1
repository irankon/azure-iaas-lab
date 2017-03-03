#Setup vnet peering

#Login to Azure and resource manager
Add-AzureAccount
Login-AzureRmAccount

#Just in case you have multiple subscriptions check which one you're working in
Get-AzureSubscription

#First get my VNETs
$vnet1 = Get-AzureRmVirtualNetwork -ResourceGroupName dmz-rg -Name dmz-vnet
$vnet2 = Get-AzureRmVirtualNetwork -ResourceGroupName hub-rg -Name hub-vnet
$vnet3 = Get-AzureRmVirtualNetwork -ResourceGroupName internal-rg -Name internal-vnet

#Setup links between the vnets
#First between the hub and DMZ
Add-AzureRmVirtualNetworkPeering -name DMZToHub-Peer -VirtualNetwork $vnet1 -RemoteVirtualNetworkId $vnet2.id
Add-AzureRmVirtualNetworkPeering -name HubToDMZ-Peer -VirtualNetwork $vnet2 -RemoteVirtualNetworkId $vnet1.id

#Then between the hub and internal vnets
Add-AzureRmVirtualNetworkPeering -name InternalToHub-Peer -VirtualNetwork $vnet3 -RemoteVirtualNetworkId $vnet2.id
Add-AzureRmVirtualNetworkPeering -name HubToInternal-Peer -VirtualNetwork $vnet2 -RemoteVirtualNetworkId $vnet3.id

#Amend with the commands below (in this case allowing Gateway transit)
# These settings are correct but you need a site-to-site vpn and to specify the peer network as a 'local network' for it to actually work
# Point-to-Site VPN doesn't allow you to do this
# Perhaps you could setup site-to-site vpn using a server 2012 box?  Need a public IP for that 2012 box....
$DMZToHubLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName dmz-vnet -ResourceGroupName dmz-rg -Name DMZToHub-Peer
$DMZToHubLink.UseRemoteGateways = $true

$InternalToHubLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName internal-vnet -ResourceGroupName internal-rg -Name InternalToHub-Peer
$InternalToHubLink.UseRemoteGateways = $true

$HubToDMZLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName hub-vnet -ResourceGroupName hub-rg -Name HubToDMZ-Peer
$HubToDMZLink.AllowGatewayTransit = $true

$HubToInternalLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName hub-vnet -ResourceGroupName hub-rg -Name HubToInternal-Peer
$HubToInternalLink.AllowGatewayTransit = $true
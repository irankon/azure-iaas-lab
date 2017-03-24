#Setup User Defined Routing (UDR)

#Login to Azure and resource manager
Add-AzureAccount
Login-AzureRmAccount

#Just in case you have multiple subscriptions check which one you're working in
Get-AzureSubscription

#If you need to select your test subscription use:
#Set-AzureSubscription -SubscriptionName <name>

##########################
# Mgmt and DMZ UDR Setup #
##########################

#Create a route from the hub to the DMZ via the inside interface of the firewall

#Get our vnet variable
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName hub-rg -Name hub-vnet

#AddressPrefix specifies the detination
#Create a route to the the DMZ web subnet via the Zentyal firewall
#NextHopIPAddress is the inside interface of the Zentyal box
$HubDMZRoute = New-AzureRmRouteConfig -Name Hub-MgmtSub-to-DMZ-WebSub `
    -AddressPrefix 192.168.1.0/24 -NextHopType VirtualAppliance `
    -NextHopIpAddress 10.2.1.4


#Create a routing table with the route to the DMZ web subnet as an entry
$routeTable = New-AzureRmRouteTable -ResourceGroupName hub-rg -Location "North Europe" `
    -Name hub-udr -Route $HubDMZRoute

#Apply to my mgmt subnet
#In this case, AddressPrefix refers to the mgmt subnet
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name mgmt-subnet `
    -AddressPrefix 10.1.1.0/24 -RouteTable $routeTable

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

#As the firewall will now be the man in the middle the DMZ VNET will see traffic coming from it
#Therefore, I need to set the peering relationship between the DMZ and Security VNETs so that forwarded traffic is accepted
$DMZToSecurityLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName dmz-vnet -ResourceGroupName dmz-rg -Name DMZToSecurity-Peer
$DMZToSecurityLink.AllowForwardedTraffic = $true
Set-AzureRmVirtualNetworkPeering -VirtualNetworkPeering $DMZToSecurityLink

#Now let's do the same from traffic in the other direction
#Create a route from the DMZ to the hub via the inside interface of the firewall

#Get our vnet variable
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName dmz-rg -Name dmz-vnet

#AddressPrefix specifies the destination
#NextHopIPAddress is the inside interface of the Zentyal box
$DMZHubRoute = New-AzureRmRouteConfig -Name DMZ-WebSub-to-Hub-MgmtSub `
    -AddressPrefix 10.1.1.0/24 -NextHopType VirtualAppliance `
    -NextHopIpAddress 10.2.1.4

$routeTable = New-AzureRmRouteTable -ResourceGroupName dmz-rg -Location "North Europe" `
    -Name dmz-udr -Route $DMZHubRoute

#Apply to my DMZ subnet
#In this case, AddressPrefix refers to the web subnet
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name web-subnet `
    -AddressPrefix 192.168.1.0/24 -RouteTable $routeTable

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

#And the on the hub side of things allow traffic forwarded from the firewall
#This will apply for all traffic from other networks to mgmt via the firewall
#because that peering relationship from the security vnet will be used generally
$HubToSecurityLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName hub-vnet -ResourceGroupName hub-rg -Name HubToSecurity-Peer
$HubToSecurityLink.AllowForwardedTraffic = $true
Set-AzureRmVirtualNetworkPeering -VirtualNetworkPeering $HubToSecurityLink


###############################
# Mgmt and Internal UDR Setup #
###############################

#Create a route from the hub to internal via the inside interface of the firewall

#Get our vnet variable
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName hub-rg -Name hub-vnet

#Update the existing hub route table with this new route
#This is key as we're updating an exsiting one so the code is slightly different
Get-AzureRmRouteTable -ResourceGroupName hub-rg -Name "hub-udr" `
  | Add-AzureRmRouteConfig -Name Hub-MgmtSub-to-Internal-ADSub -AddressPrefix 172.1.1.0/24 -NextHopType VirtualAppliance -NextHopIpAddress 10.2.1.4 `
  | Set-AzureRmRouteTable

$routeTable = Get-AzureRmRouteTable -ResourceGroupName hub-rg -Name "hub-udr"

#Apply to my mgmt subnet
#In this case, AddressPrefix refers to the mgmt subnet
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name mgmt-subnet `
    -AddressPrefix 10.1.1.0/24 -RouteTable $routeTable

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

#Now let's do the same from traffic in the other direction
#Create a route from Internal to the hub via the inside interface of the firewall

#Get our vnet variable
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName internal-rg -Name internal-vnet

#AddressPrefix specifies the destination
#NextHopIPAddress is the inside interface of the Zentyal box
$InternalHubRoute = New-AzureRmRouteConfig -Name Internal-ADSub-to-Hub-MgmtSub `
    -AddressPrefix 10.1.1.0/24 -NextHopType VirtualAppliance `
    -NextHopIpAddress 10.2.1.4

$routeTable = New-AzureRmRouteTable -ResourceGroupName internal-rg -Location "North Europe" `
    -Name internal-udr -Route $InternalHubRoute

#Apply to my internal AD subnet
#In this case, AddressPrefix refers to the AD subnet
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name ad-subnet `
    -AddressPrefix 172.1.1.0/24 -RouteTable $routeTable

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

#As the firewall will now be the man in the middle the Internal VNET will see traffic coming from it
#Therefore, I need to set the peering relationship between the Internal and Security VNETs so that forwarded traffic is accepted
$InternalToSecurityLink = Get-AzureRmVirtualNetworkPeering -VirtualNetworkName internal-vnet -ResourceGroupName internal-rg -Name InternalToSecurity-Peer
$InternalToSecurityLink.AllowForwardedTraffic = $true
Set-AzureRmVirtualNetworkPeering -VirtualNetworkPeering $InternalToSecurityLink

###############################
# DMZ and Internal UDR Setup #
###############################

#Create a route from the DMZ to internal via the inside interface of the firewall

#Get our vnet variable
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName dmz-rg -Name dmz-vnet

#Update the existing dmz route table with this new route
#This is key as we're updating an exsiting one so the code is slightly different
Get-AzureRmRouteTable -ResourceGroupName dmz-rg -Name "dmz-udr" `
  | Add-AzureRmRouteConfig -Name DMZ-WebSub-to-Internal-ADSub -AddressPrefix 172.1.1.0/24 -NextHopType VirtualAppliance -NextHopIpAddress 10.2.1.4 `
  | Set-AzureRmRouteTable

$routeTable = Get-AzureRmRouteTable -ResourceGroupName dmz-rg -Name "dmz-udr"

#Apply to my dmz web subnet
#In this case, AddressPrefix refers to the mgmt subnet
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name web-subnet `
    -AddressPrefix 192.168.1.0/24 -RouteTable $routeTable

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

#Now let's do the same from traffic in the other direction
#Create a route from Internal to the dmz via the inside interface of the firewall

#Get our vnet variable
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName internal-rg -Name internal-vnet

#Update the existing internal route table with this new route
#This is key as we're updating an exsiting one so the code is slightly different
Get-AzureRmRouteTable -ResourceGroupName internal-rg -Name "internal-udr" `
  | Add-AzureRmRouteConfig -Name Internal-ADSub-to-DMZ-WebSub -AddressPrefix 192.168.1.0/24 -NextHopType VirtualAppliance -NextHopIpAddress 10.2.1.4 `
  | Set-AzureRmRouteTable

$routeTable = Get-AzureRmRouteTable -ResourceGroupName internal-rg -Name "internal-udr"

#Apply to my internal AD subnet
#In this case, AddressPrefix refers to the mgmt subnet
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name AD-subnet `
    -AddressPrefix 172.1.1.0/24 -RouteTable $routeTable

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
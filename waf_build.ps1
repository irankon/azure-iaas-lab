#Create the WAF frontend

#Login to Azure and resource manager
Add-AzureAccount
Login-AzureRmAccount

#Just in case you have multiple subscriptions check which one you're working in
Get-AzureSubscription

#If you need to select your test subscription use:
#Set-AzureSubscription -SubscriptionName <name>

#Add a WAF in front of the DMZ web VM
$RGName = "dmz-rg"
$Location = "North Europe"

#First the WAF needs a subnet.  This doesn't need to be big so a /28 would work under normal circumstances
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName  -Name dmz-vnet

Add-AzureRmVirtualNetworkSubnetConfig -Name waf-subnet `
    -VirtualNetwork $vnet -AddressPrefix 192.168.2.0/28

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

#Setup variables in prep for creating the WAF
$vnet = Get-AzureRmvirtualNetwork -ResourceGroupName $RGName  -Name dmz-vnet
$WAFSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name 'waf-subnet' -VirtualNetwork $vnet
$WebSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name 'web-subnet' -VirtualNetwork $vnet

#Create a public IP for the WAF to use
$WAFPIP = New-AzureRmPublicIpAddress -ResourceGroupName $RGName -name 'waf-pip' -Location $Location -AllocationMethod Dynamic

#Setup WAF config
$WAFIPConfig = New-AzureRmApplicationGatewayIPConfiguration -Name 'waf-conf' -Subnet $WAFSubnet

#Define your backend (DMZ) subnet config details
$WebPool = New-AzureRmApplicationGatewayBackendAddressPool -Name 'web-pool' -BackendIPAddresses 192.168.1.4

$WebPoolSetting = New-AzureRmApplicationGatewayBackendHttpSettings -Name 'dmz-testsite' -Port 80 -Protocol Http -CookieBasedAffinity Enabled

#Configure the frontend VIP
$WAFFrontendPort = New-AzureRmApplicationGatewayFrontendPort -Name 'dmz-testsite-port-80' -Port 80

$WAFFrontendIPConfig = New-AzureRmApplicationGatewayFrontendIPConfig -Name 'dmz-testsite-80' -PublicIPAddress $WAFPIP

#Create an HTTP listener for the WAF
$WAFListener = New-AzureRmApplicationGatewayHttpListener -Name dmz-testsite-listener-80 -Protocol Http -FrontendIPConfiguration $WAFFrontendIPConfig -FrontendPort $WAFFrontendPort

#Set basic round-robin load-balancing (even though we only have one server)
$WAFLoadRule = New-AzureRmApplicationGatewayRequestRoutingRule -Name 'dmz-testsite-rule' -RuleType basic -BackendHttpSettings $WebPoolSetting -HttpListener $WAFListener -BackendAddressPool $WebPool

#Set the WAF instance size
$WAFSKU = New-AzureRmApplicationGatewaySku -Name WAF_Medium -Tier WAF -Capacity 2

#Set the mode to detection
$WAFConfig = New-AzureRmApplicationGatewayWebApplicationFirewallConfiguration -Enabled $true -FirewallMode "Detection"

#Finally create the WAF
$WAF = New-AzureRmApplicationGateway -Name dmz-waf -ResourceGroupName $RGName -Location $Location -BackendAddressPools $WebPool -BackendHttpSettingsCollection $WebPoolSetting -FrontendIpConfigurations $WAFFrontendIPConfig -GatewayIpConfigurations $WAFIPConfig -FrontendPorts $WAFFrontendPort -HttpListeners $WAFListener -RequestRoutingRules $WAFLoadRule -Sku $WAFSKU -WebApplicationFirewallConfiguration $WAFConfig
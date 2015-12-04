#################################################################
#Created: Austin Heyne											#
#Date: Nov 2012													#
#Contact: aheyne@ou.edu											#
#																#
#Info: For help use get-help.									#
#																#
#################################################################

<#
	
.SYNOPSIS
	Easily configure basic Server settings in CLI environment.
.DESCRIPTION	
	Process All
		Runs IpConfig, Config Firewall, and Join Domain
	
	IpConfig
		Allows you to set Static IP, Subnet Mask, Gatway, DNS, and IPV6
	
	Config Firewall
		Basic on/off configuration of Domain, Private, and Public Firewalls
	
	Join Domain
		Allows you to join a domain. Server must reboot for this to take effect.
		
	Install Gui
		Will initiate the gui install. Note this will reboot the server.
		
.NOTES
	Please don't name a network adapter q.

.PARAMETER Verbose
	Provides a lot more information.
	
.EXAMPLE
	.\ServerSetup.ps1 -verbose
	
#>

[cmdletbinding()]
param()

function Main (){
	$Answer = MainPrompt

	switch ($Answer)
	{
		0{process-all}
		1{process-ipconfig}
		2{process-configfirewall}
		3{process-joindomain}
		4{process-renamecomputer}
		5{process-installgui}
		6{process-quit}
	}
}

function MainPrompt (){
	$A = ([System.Management.Automation.Host.ChoiceDescription]"&All, Run")
	$A.helpmessage = "Runs IP, Firewall, Computername and Domain configurations."
	$I = ([System.Management.Automation.Host.ChoiceDescription]"&IP Config")
	$I.helpmessage = "Configure the network adapters."
	$F = ([System.Management.Automation.Host.ChoiceDescription]"&Config Firewalls")
	$F.helpmessage = "Disable/Enable Firewalls and modify exceptions."
	$D = ([System.Management.Automation.Host.ChoiceDescription]"&Join Domain")
	$D.helpmessage = "Join Computer to Domain."
	$H = ([System.Management.Automation.Host.ChoiceDescription]"&Rename Computer")
	$H.helpmessage = "Rename the computer"
	$G = ([System.Management.Automation.Host.ChoiceDescription]"&GUI Install")
	$G.helpmessage = "Install windows graphical user interface."
	$Q = ([System.Management.Automation.Host.ChoiceDescription]"&Quit")
	$Q.helpmessage = "Quit"

	$Caption = "Main Menu"
	$Message = "What do you want to Configure?"
	$Choices = ($A,$I,$F,$D,$H,$G,$Q)
	$host.ui.PromptForChoice($Caption,$Message,[System.Management.Automation.Host.ChoiceDescription[]]$Choices,6)

}

function process-all (){
	process-ipconfig
	process-configfirewall
	process-joindomain
}

function process-ipconfig (){
	config-netadapters
}

function process-configfirewall (){
	config-firewall
}

function process-joindomain (){
	Write-Host "Join a Domain."
	change-computername
	join-domain
}

function process-renamecomputer (){
	change-computername
}
function process-installgui (){
	Write-Host "Server GUI install."
	Write-Host "The Server will reboot during this process."
	$ans = Read-Host "Are you sure you want to continue? [yes/n]"
	while($ans -eq "y"){
		$ans = Read-Host "Please type 'yes'"
	}
	if($ans -ne "yes"){return}
	else{enable-gui}
}

function process-quit (){
	Write-Host("Quiting...")
	Exit -1
}

function config-netadapters (){
	$key = $true
While($key){
	$bla = Get-NetIPInterface
		$bla
	$selection = Read-Host "Select card by ifIndex; q to quit" #Please don't name a NIC q...
	if($selection -eq "q"){
		$key = $false
	}else{
		Write-Host "Interface" $selection "selected."
		
		#renaming
		$newname = Read-Host "Enter new name (vlan)"
		if($PSBoundParameters['Verbose']){Write-Host "Using Rename-NetAdapter"}
		$cardname = $(Get-NetIPInterface | where{$_.InterfaceIndex -eq $selection}).InterfaceAlias
		Rename-NetAdapter -Name $cardname $newname
		Write-Host "Renamed."
		
		#change IP Address/subnetmask/gateway
		$newIP = Read-Host "IP Address"
		[System.Net.IPAddress]$newsubnetmask = Read-Host "Subnet Mask" #needs to be ipaddress cast for bits function
		$cidr = convert-subnetmask $newsubnetmask
		Write-Host "Gateway can be left blank if needed."
		$newgateway = Read-Host "Gateway"
		if($PSBoundParameters['Verbose']){
			Write-Host "CIDR converseion" $cidr
			Write-Host "Using New-NetIPAddress"
		}
		if($gateway -eq $null){
			New-NetIPAddress -InterfaceIndex $selection -IPAddress $newIP -AddressFamily IPv4 -PrefixLength $cidr 
		}else{
			New-NetIPAddress -InterfaceIndex $selection -IPAddress $newIP -AddressFamily IPv4 -PrefixLength $cidr -DefaultGateway $newgateway
		}
		Write-Host "IP Address settings applied."
		
		#change Dns servers
		Write-Host "This version of Server Setup cannot change back to Auto DNS because I can't figure out how."
		$adns = Read-Host "Enter DNS? [y/n]"
		if($adns -like "y"){
			$newdns1 = Read-Host "Enter preferred DNS"
			$newdns2 = Read-Host "Enter alternate DNS"
			if($PSBoundParameters['Verbose']){Write-Host "Using Set-DnsClientServerAddress"}
			Set-DnsClientServerAddress -InterfaceIndex $selection -ServerAddresses $newdns1,$newdns2
			Write-Host "DNS settings applied."
			if($PSBoundParameters['Verbose']){
				Write-Host "Updated Settings"
				Get-DNSClientServerAddress -InterfaceIndex $selection
			}
		}
	
		#Change ipv6
		$ipv6 = Read-Host "Disable IPV6? [y/n]"
		if($ipv6 -eq "y"){
			if($PSBoundParameters['Verbose']){Write-Host "Using Disable-NetAdapterBinding"}
			Disable-NetAdapterBinding -InterfaceAlias $newname -ComponentID  ms_tcpip6
			Write-Host "IPV6 disabled."
		}		
	}
}
}

function join-domain (){
	Add-Computer
	$ans = Read-Host "Do you need to add a domain user accound to the loacl Administrators group? [y/n]"
	if($ans -eq "y"){
		$domainname = Read-Host "Domain"
		$username = Read-Host "Username"
		if($PSBoundParameters['Verbose']){Write-Host "Using net localgroup administrators /add <DomainName>\<UserName>"}
		net localgroup administrators /add $domainname\$username
	}
	Write-Host "Changes have been applied but the server needs to be restarted for them to take effect."
	$ans = Read-Host "Would you like to restart the server now? [yes/n]"
	while($ans -eq "y"){$ans = Read-Host "Please type 'yes'"}
	if($ans -eq "yes"){
		Restart-Computer
	}
	return
}

function change-computername (){
	$ans = Read-Host "Current computer name:" $(hostname) "Change? [y/n]"
	if($ans -eq "y"){
		Rename-Computer -NewName $(Read-Host "New Name")
	}else{return}
	Write-Host "Changes have been applied but the server needs to be restarted for them to take effect."
	$ans = Read-Host "Would you like to restart the server now? [yes/n]"
	while($ans -eq "y"){$ans = Read-Host "Please type 'yes'"}
	if($ans -eq "yes"){
		Restart-Computer
	}
}

function enable-gui (){
	Write-Host "Starting Gui install..."
	if($PSBoundParameters['Verbose']){Write-Host "Install-WindowsFeature Server-Gui-Shell, Server-Gui-Mgmt-Infra"}
	$path = "\\it-bania\files\OS\Windows Server 2012\sources"
	Install-WindowsFeature Server-Gui-Shell, Server-Gui-Mgmt-Infra -source $path
}

function config-firewall (){
	$key = $true
while($key){
	if($PSBoundParameters['Verbose']){Write-Host "Using Get-NetFirewallProfile"}
	$data = $null
	$data = Get-NetFirewallProfile
	Write-Host "`nCurrent Status"
	Write-Host "Firewall`tStatus"
	Write-Host "--------`t------"
	if($data[0].Enabled -eq "True"){
		Write-Host "Domain `t`tEnabled"
	}else{
		Write-Host "Domain `t`tDisabled"
	}
	if($data[1].Enabled -eq "True"){
		Write-Host "Private`t`tEnabled"
	}else{
		Write-Host "Private`t`tDisabled"
	}
	if($data[2].Enabled -eq "True"){
		Write-Host "Public `t`tEnabled"
	}else{
		Write-Host "Public `t`tDisabled"
	}
	Write-Host "`nPlease Choose a function"
	Write-Host "1: Enable All"
	Write-Host "2: Disable ALL"
	Write-Host "3: Toggle Domain"
	Write-Host "4: Toggle Private"
	Write-Host "5: Toggle Public"
	Write-Host "6: Back to Main Menu"
	
	$ans = Read-Host "Please choose a function"
	
	switch($ans){
		1 {#Enable All
			Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
			Write-Host "All Firewalls Enabled"
		}
		2 {#Disable ALL
			Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
			Write-Host "All Firewalls Disabled"
		}
		3 {#Toggle Domain
			if($data[0].Enabled){
				Set-NetFirewallProfile -Profile Domain -Enabled False
				Write-Host "Domain Firewall Disabled"
			}else{
				Set-NetFirewallProfile -Profile Domain -Enabled True
				Write-Host "Domain Firewall Enabled"
			}
		}
		4 {#Toggle Private
			if($data[1].Enabled){
				Set-NetFirewallProfile -Profile Private -Enabled False
				Write-Host "Private Firewall Diabled"
			}else{
				Set-NetFirewallProfile -Profile Private -Enabled True
				Write-Host "Private Firewall Enabled"
			}
		}
		5 {#Toggle Public
			if($data[2].Enabled){
				Set-NetFirewallProfile -Profile Public -Enabled False
				Write-Host "Public Firewalled Disabled"
			}else{
				Set-NetFirewallProfile -Profile Public -Enabled True
				Write-Host "Public Firewall Enabled"
			}
		}
		6 {#Back to Main Menu
			$key = $false
		}
	}
}}

function convert-subnetmask ($subnetmask){
	#Here to convert subnetmask to cidr notation for use in Set-NetIpAddress.
	$bla = $subnetmask.GetAddressBytes()
	$bits = @(1,2,3,4)
	for($i=0;$i -lt $bla.length;$i++){
		$bits[$i] = [math]::abs(255-$bla[$i])
	}
	for($i=0;$i -lt $bits.length;$i++){
		if($bits[$i] -ne 0){
			$bits[$i] += 1
			$two = 0
			while($bits[$i] -ne 1){
				$bits[$i] = ($bits[$i] / 2)
				$two++
			}
			$bits[$i] = $two
		}
		$cidr += $bits[$i]
	}
	$cidr = 32 - $cidr
	return $cidr
}

#Script
Write-Host -foregroundcolor Green -backgroundcolor Black "Windows Server 2012 CLI Setup Script."
if($PSBoundParameters['Verbose']){Write-Host -foregroundcolor Green -backgroundcolor Black "Verbose Mode!"}
while ($true) {
	Main
}

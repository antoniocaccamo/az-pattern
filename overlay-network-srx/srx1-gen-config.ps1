################# Load the value of parameters from init.json file #################
# Load Initialization Variables
$ScriptDir = Split-Path -Parent $PSCommandPath
If (Test-Path -Path $ScriptDir\init.json){
        $content=Get-Content -Raw -Path $ScriptDir\init.json 
}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

$json=ConvertFrom-Json -InputObject $content 

if ( $json -ne $null ) 
{
    foreach ($e in $json) 
    {
       if (-not([string]::IsNullOrEmpty($e.siteA))) { Write-Host (Get-Date)' - ' -NoNewline; Write-host "SiteA is not null.OK!" } else { Write-Host "siteA EMPTY" ; Return }
       if (-not([string]::IsNullOrEmpty($e.siteB))) { Write-Host (Get-Date)' - ' -NoNewline; Write-host "SiteB is not null.OK!" } else { Write-Host "siteB EMPTY" ; Return }
    }
}

if ($json.siteA.subscriptionName) { Write-host "siteA-subscription..:"$json.siteA.subscriptionName -ForegroundColor Green } else { Write-Host "siteA-subscription"; Return }
if ($json.siteA.srx1_vmName)      { Write-host "siteA-srx1 name.....:"$json.siteA.srx1_vmName -ForegroundColor Green }      else { Write-Host "siteA-srx1 name EMPTY"; Return }
if ($json.siteA.rgName)           { Write-host "siteA-resource group:"$json.siteA.rgName -ForegroundColor Green }           else { Write-Host "siteA-resource group EMPTY"; Return }

if ($json.siteB.subscriptionName) { Write-host "siteB-subscription..:"$json.siteB.subscriptionName -ForegroundColor Cyan }  else { Write-Host "siteB-subscription"; Return }
if ($json.siteB.srx1_vmName)      { Write-host "siteB-srx1 name.....:"$json.siteB.srx1_vmName -ForegroundColor Cyan }       else { Write-Host "siteB-srx1 name EMPTY"; Return }
if ($json.siteB.rgName)           { Write-host "siteB-resource group:"$json.siteB.rgName -ForegroundColor Cyan }            else { Write-Host "siteB-resource group EMPTY"; Return }
################# End parameters ###################


$rgLocal=$json.siteA.rgName
$rgRemote=$json.siteB.rgName
$nicNameLocal=$json.siteA.srx1_vmName+'-ge-0-0-0'
$nicNameRemote=$json.siteB.srx1_vmName+'-ge-0-0-0'

Try {
  $ip_srx_Local=(Get-AzPublicIpAddress  -ResourceGroupName $rgLocal -Name $nicNameLocal -ErrorAction Stop).IpAddress }
catch {
 Write-Host (Get-Date)' - ' -NoNewline
 Write-Host (Get-Date)'Error getting the public IP associated with NIC: $nicNameLocal' -NoNewline
 Exit
}
Try {$ip_srx_Remote=(Get-AzPublicIpAddress  -ResourceGroupName $rgRemote -Name $nicNameRemote -ErrorAction Stop).IpAddress }
catch {
 Write-Host (Get-Date)' - ' -NoNewline
 Write-Host (Get-Date)'Error getting the public IP associated with NIC: $nicNameRemote' -NoNewline
 Exit
}

Write-Host "IP Local....: "$ip_srx_Local -ForegroundColor Yellow
Write-Host "IP Remote...: "$ip_srx_Remote -ForegroundColor Yellow


############# 
$tunnelLocalIP="192.168.1.1"
$tunnelLocalMask="/30"
$tunnelRemoteIP="192.168.1.2"
$loopbackLocalIP="172.16.1.1"
$loopbackLocalMask="/32"
$loopbackRemoteIP= "172.16.1.2"
$greLocalIP="172.16.255.1"
$greLocalMask="/30"
$vpnGtwLocalPubIP=$ip_srx_Local
$vpnGtwRemotePubIP=$ip_srx_Remote
$srx_untrustedInterface_privIP="10.0.1.33"
$presharedKey= "Mysharedpwd*01"

$fileName="srx1-config.txt"

# replace the special characters but it keeps the set of characters: ), (, }, {, *, -
$presharedKey1=$presharedKey -replace'[^\p{L}\p{Nd}/)/(/}/{/_/*/-]', ''
$presharedKey="`""+$presharedKey1+"`""





$srxConfig = @"
### Enabling the mgmt_junos Routing Instance
### The name of the dedicated management instance is reserved and hardcoded as mgmt_junos; 
### you are prevented from configuring any other routing instance by the name mgmt_junos. 
### Once the mgmt_junos routing instance is deployed, management traffic no longer shares a routing table 
### (that is, the default inet.0 table) with other control or protocol traffic in the system
### Tables for the mgmt_junos table are set up for inet and inet6 and marked as private tables. 
### The management interface is moved to the mgmt_junos routing table.
### At the point where you commit the configuration, if you are using SSH or telnet, 
### the connection to the device will be dropped and you will have to reestablish it. 

set routing-instances mgmt_junos description "management routing instance"
set system management-instance

### Configure the physical and logical interfaces
set interfaces ge-0/0/0 description "Internet"
set interfaces ge-0/0/0 mtu 1514
set interfaces ge-0/0/0 unit 0 family inet dhcp

set interfaces gr-0/0/0 unit 0 description "MPLS core facing interface"
set interfaces gr-0/0/0 unit 0 tunnel source $tunnelLocalIP
set interfaces gr-0/0/0 unit 0 tunnel destination $tunnelRemoteIP
set interfaces gr-0/0/0 unit 0 family inet mtu 1514
set interfaces gr-0/0/0 unit 0 family inet address $greLocalIP$greLocalMask
set interfaces gr-0/0/0 unit 0 family mpls mtu 1514
set interfaces gr-0/0/0 unit 0 family mpls filter input packet-mode
set interfaces lo0 unit 0 family inet address $loopbackLocalIP$loopbackLocalMask
set interfaces st0 unit 0 description "VPN tunnel"
set interfaces st0 unit 0 family inet mtu 1436 
set interfaces st0 unit 0 family inet address $tunnelLocalIP$tunnelLocalMask

# Configure the firewall filters that are used to configure interfaces to work with packet mode.
set firewall family inet filter packet-mode-inet term all-traffic then packet-mode
set firewall family inet filter packet-mode-inet term all-traffic then accept
set firewall family mpls filter packet-mode term all-traffic then packet-mode
set firewall family mpls filter packet-mode term all-traffic then accept

#
set interfaces ge-0/0/1 description "LAN Side"
set interfaces ge-0/0/1 mtu 1514
set interfaces ge-0/0/1 unit 0 description blue-vrf
set interfaces ge-0/0/1 unit 0 family inet filter input packet-mode-inet
set interfaces ge-0/0/1 unit 0 family inet dhcp

set interfaces ge-0/0/2 description "LAN Side"
set interfaces ge-0/0/2 mtu 1514
set interfaces ge-0/0/2 unit 0 description red-vrf
set interfaces ge-0/0/2 unit 0 family inet filter input packet-mode-inet
set interfaces ge-0/0/2 unit 0 family inet dhcp


#Set up the trust security zone.
set security zone security-zone trust1 host-inbound-traffic system-services all
set security zone security-zone trust1 host-inbound-traffic protocols bgp
set security zone security-zone trust1 interfaces ge-0/0/1.0
###
#Set up the trust security zone.
set security zone security-zone trust2 host-inbound-traffic system-services all
set security zone security-zone trust2 host-inbound-traffic protocols bgp
set security zone security-zone trust2 interfaces ge-0/0/2.0

#Set up the Internet security zone.
set security zones security-zone Internet host-inbound-traffic system-services all
set security zones security-zone Internet host-inbound-traffic protocols all
set security zones security-zone Internet interfaces ge-0/0/0.0
set security zones security-zone Internet interfaces gr-0/0/0.0
set security zones security-zone Internet interfaces lo0.0
set security zones security-zone Internet interfaces st0.0

### Set security policy
set security policies from-zone trust1 to-zone trust1 policy default-permit match source-address any
set security policies from-zone trust1 to-zone trust1 policy default-permit match destination-address any
set security policies from-zone trust1 to-zone trust1 policy default-permit match application any
set security policies from-zone trust1 to-zone trust1 policy default-permit then permit

set security policies from-zone trust2 to-zone trust2 policy default-permit match source-address any
set security policies from-zone trust2 to-zone trust2 policy default-permit match destination-address any
set security policies from-zone trust2 to-zone trust2 policy default-permit match application any
set security policies from-zone trust2 to-zone trust2 policy default-permit then permit


### Configure all noncustomer-facing interfaces in a single security zone and a policy to permit all (intrazone) traffic.
set security policies from-zone Internet to-zone Internet policy Internet match source-address any
set security policies from-zone Internet to-zone Internet policy Internet match destination-address any
set security policies from-zone Internet to-zone Internet policy Internet match application any
set security policies from-zone Internet to-zone Internet policy Internet then permit

set security policies from-zone Internet to-zone trust1 policy default-permit match source-address any
set security policies from-zone Internet to-zone trust1 policy default-permit match destination-address any
set security policies from-zone Internet to-zone trust1 policy default-permit match application any
set security policies from-zone Internet to-zone trust1 policy default-permit then permit

set security policies from-zone Internet to-zone trust2 policy default-permit match source-address any
set security policies from-zone Internet to-zone trust2 policy default-permit match destination-address any
set security policies from-zone Internet to-zone trust2 policy default-permit match application any
set security policies from-zone Internet to-zone trust2 policy default-permit then permit

set security policies from-zone trust1 to-zone Internet policy default-permit match source-address any
set security policies from-zone trust1 to-zone Internet policy default-permit match destination-address any
set security policies from-zone trust1 to-zone Internet policy default-permit match application any
set security policies from-zone trust1 to-zone Internet policy default-permit then permit

set security policies from-zone trust2 to-zone Internet policy default-permit match source-address any
set security policies from-zone trust2 to-zone Internet policy default-permit match destination-address any
set security policies from-zone trust2 to-zone Internet policy default-permit match application any
set security policies from-zone trust2 to-zone Internet policy default-permit then permit


#Configure IKE.
set security ike proposal ike-proposalA authentication-method pre-shared-keys
set security ike proposal ike-proposalA dh-group group2
set security ike proposal ike-proposalA authentication-algorithm sha-256
set security ike proposal ike-proposalA encryption-algorithm aes-256-cbc
set security ike proposal ike-proposalA lifetime-seconds 1800

### Configure the IKE and IPsec policies.
set security ike policy ike-policyA mode main
set security ike policy ike-policyA proposals ike-proposalA
set security ike policy ike-policyA pre-shared-key ascii-text $presharedKey 

set security ike gateway gtw-A ike-policy ike-policyA
set security ike gateway gtw-A address $vpnGtwRemotePubIP
set security ike gateway gtw-A local-identity inet $vpnGtwLocalPubIP
set security ike gateway gtw-A external-interface ge-0/0/0.0
set security ike gateway gtw-A version v2-only
set security ike gateway gtw-A dead-peer-detection

#Configure IPsec.
set security ipsec proposal ipsec-proposalA protocol esp
set security ipsec proposal ipsec-proposalA authentication-algorithm hmac-sha1-96
set security ipsec proposal ipsec-proposalA encryption-algorithm aes-256-cbc
set security ipsec proposal ipsec-proposalA lifetime-seconds 3600

set security ipsec policy ipsec-policy-siteA proposals ipsec-proposalA

set security ipsec vpn ipsec-vpn-1 bind-interface st0.0
set security ipsec vpn ipsec-vpn-1 df-bit clear
set security ipsec vpn ipsec-vpn-1 ike gateway gtw-A
set security ipsec vpn ipsec-vpn-1 ike ipsec-policy ipsec-policy-siteA
set security ipsec vpn ipsec-vpn-1 establish-tunnels immediately
set security flow tcp-mss ipsec-vpn mss 1387


### routing protocol
### Configure the OSPF protocol for lo0.0 address distribution, and configure IBGP with the inet-vpn and l2vpn families.
set protocols mpls interface gr-0/0/0.0
set protocols bgp tcp-mss 1200
set protocols bgp group IBGP type internal
set protocols bgp group IBGP local-address $loopbackLocalIP
set protocols bgp group IBGP local-as 65001
set protocols bgp group IBGP neighbor $loopbackRemoteIP
set protocols bgp group IBGP neighbor $loopbackRemoteIP family inet any
set protocols bgp group IBGP neighbor $loopbackRemoteIP family inet-vpn any
set protocols ospf traffic-engineering
set protocols ospf area 0.0.0.0 interface lo0.0
set protocols ospf area 0.0.0.0 interface lo0.0 passive
set protocols ospf area 0.0.0.0 interface gr-0/0/0.0
set protocols ldp interface gr-0/0/0.0
set protocols ldp interface lo0.0

# Configure two routing instances, one for Layer 3 VPN: blue-vrf and red-vrf
set routing-instances blue-vrf instance-type vrf
set routing-instances blue-vrf interface ge-0/0/1.0
set routing-instances blue-vrf route-distinguisher 10:10
set routing-instances blue-vrf vrf-target target:65001:10
set routing-instances blue-vrf vrf-target import target:65001:10
set routing-instances blue-vrf vrf-target export target:65001:10
set routing-instances blue-vrf vrf-table-label
set routing-instances blue-vrf routing-options auto-export

set routing-instances red-vrf instance-type vrf
set routing-instances red-vrf interface ge-0/0/2.0
set routing-instances red-vrf route-distinguisher 20:20
set routing-instances red-vrf vrf-target target:65001:20
set routing-instances red-vrf vrf-target import target:65001:20
set routing-instances red-vrf vrf-target export target:65001:20
set routing-instances red-vrf vrf-table-label
set routing-instances red-vrf routing-options auto-export

set routing-options static route 0.0.0.0/0 next-hop $srx_untrustedInterface_privIP

"@
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $srxConfig 
Connect-NsxServer -vCenterServer vcsa-01a.corp.local -Username administrator@corp.local -Password VMware1!

$WebLs = Get-NsxLogicalSwitch -name WEB-LS

Get-Vm fin-web-01a_corp.local | Connect-NsxLogicalSwitch -LogicalSwitch $WebLs
Get-Vm hr-web-01a_corp.local | Connect-NsxLogicalSwitch -LogicalSwitch $WebLs

$MC = New-NsxIpSet -Name "Main Console" -IPAddresses "192.168.110.10"
$STCA = New-NsxSecurityTag -Name Customer-Application
$STCA | New-NsxSecurityTagAssignment -ApplytoVM -VirtualMachine (Get-VM web-01a_corp.local),(Get-VM web-02a_corp.local),(Get-VM app-01a_corp.local),(Get-VM db-01a_corp.local)

$MyApp = New-NsxService "MyApp" -Protocol TCP -port 8443

$LVMSG = New-NsxSecurityGroup "Linux VM Security Group" -IncludeMember (Get-VM web-01a_corp.local),(Get-VM web-02a_corp.local),(Get-VM app-01a_corp.local),(Get-VM db-01a_corp.local),(Get-VM fin-web-01a_corp.local),(Get-VM fin-app-01a_corp.local),(Get-VM fin-db-01a_corp.local),(Get-VM hr-web-01a_corp.local),(Get-VM hr-app-01a_corp.local),(Get-VM hr-db-01a_corp.local)

$ASG = New-NsxSecurityGroup "App Security Group" -IncludeMember (Get-VM app-01a_corp.local),(Get-VM hr-app-01a_corp.local),(Get-VM fin-app-01a_corp.local)
$DSG = New-NsxSecurityGroup "DB Security Group" -IncludeMember (Get-VM db-01a_corp.local),(Get-VM hr-db-01a_corp.local),(Get-VM fin-db-01a_corp.local)
$WSG = New-NsxSecurityGroup "Web Security Group" -IncludeMember (Get-VM web-01a_corp.local),(Get-VM web-02a_corp.local),(Get-VM hr-web-01a_corp.local),(Get-VM fin-web-01a_corp.local)

$CASG = New-NsxSecurityGroup "Customer App Security Group" -IncludeMember (Get-VM web-01a_corp.local),(Get-VM web-02a_corp.local),(Get-VM app-01a_corp.local),(Get-VM db-01a_corp.local)
$FASG = New-NsxSecurityGroup "Finance App Security Group" -IncludeMember (Get-VM fin-web-01a_corp.local),(Get-VM fin-app-01a_corp.local),(Get-VM fin-db-01a_corp.local)
$HRSG = New-NsxSecurityGroup "Finance App Security Group" -IncludeMember (Get-VM hr-web-01a_corp.local),(Get-VM hr-app-01a_corp.local),(Get-VM hr-db-01a_corp.local)

$IR = New-NsxFirewallSection -name "Infrastrucutre Rules"
$ER = New-NsxFirewallSection -name "Environment Rules" -position after -anchorId $IR.id
$ITI = New-NsxFirewallSection -name "Intra-Tier-Isolation" -position after -anchorId $ER.id
$IEAR = New-NsxFirewallSection -name "Inter-Application Rules" -position after -anchorId $ITI.id
$IAAR = New-NsxFirewallSection -name "Intra-Application Rules" -position after -anchorId $IEAR.id

$IR | New-NsxFirewallRule -name "DC Services Access" -source $LVMSG -destination $MC -Service (Get-NsxService DNS-UDP -LocalOnly),(Get-NsxService DNS -LocalOnly),(Get-NsxService NTP -LocalOnly),(Get-NsxService LDAP -LocalOnly) -Action "allow" -AppliedTo $LVMSG
Get-NsxFirewallSection -name "Infrastrucutre Rules" | New-NsxFirewallRule -name "SSH Access to Linux VMs" -source $MC -destination $LVMSG -Service (Get-NsxService SSH -LocalOnly) -Action "allow" -AppliedTo $LVMSG

$ER | New-NsxFirewallRule -name "Web Access" -destination $WSG -Service (Get-NsxService HTTPS -LocalOnly) -Action "allow" -AppliedTo $WSG

$ITI | New-NsxFirewallRule -name "Web Tier Isolation" -source $WSG -destination $WSG -Action "block"

$IEAR | New-NsxFirewallRule -name "Finance App Isolation" -source $FASG -destination $FASG -NegateDestination -Action "block" -AppliedTo $FASG
Get-NsxFirewallSection -name "Inter-Application Rules" | New-NsxFirewallRule -name "HR App Isolation" -source $HRSG -destination $HRSG -NegateDestination -Action "block" -AppliedTo $HRSG
Get-NsxFirewallSection -name "Inter-Application Rules" | New-NsxFirewallRule -name "Customer App Isolation" -source $CASG -destination $CASG -NegateDestination -Action "block" -AppliedTo $CASG

$IAAR | New-NsxFirewallRule -name "Web-Tier to App-Tier" -source $WSG -destination $ASG -Service $MyApp -Action "allow"
Get-NsxFirewallSection -name "Intra-Application Rules" | New-NsxFirewallRule -name "App-Tier to DB-Tier" -source $ASG -destination $DSG -Service (Get-NsxService HTTP -LocalOnly) -Action "allow"

Get-NsxFirewallSection -name "Default Section Layer3" | Get-NsxFirewallRule -name "Default Rule" | Set-NsxFirewallRule -name "Default Rule" -action "deny"

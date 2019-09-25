Connect-NsxServer -vCenterServer vcsa-01a.corp.local -Username administrator@corp.local -Password VMware1!

$TZ = Get-NsxTransportZone -Name RegionA0-Global-TZ
$WebLs = $TZ | New-NsxLogicalSwitch -Name WEB-LS
$DLR = Get-NsxLogicalRouter DLR-01
$LIF = $DLR | New-NsxLogicalRouterInterface -Name "WEB-LS" -ConnectedTo $WebLs -PrimaryAddress "172.16.10.1" -SubnetPrefixLength "24" -Connected -Type internal

Get-Vm web-01a_corp.local | Connect-NsxLogicalSwitch -LogicalSwitch $WebLs
Get-Vm web-02a_corp.local | Connect-NsxLogicalSwitch -LogicalSwitch $WebLs

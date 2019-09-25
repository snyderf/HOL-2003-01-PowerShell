Connect-NsxServer -vCenterServer vcsa-01a.corp.local -Username administrator@corp.local -Password VMware1!

#Configure DLR for Routing:
Get-NsxLogicalRouter DLR-01
Get-NsxLogicalRouter DLR-01 | Get-NsxLogicalRouterRouting | Set-NsxLogicalRouterRouting -EnableBgp -ProtocolAddress 172.16.0.11 -ForwardingAddress 172.16.0.10 -LocalAS 65001 -RouterId 172.16.0.10 -confirm:$false
Get-NsxLogicalRouter DLR-01 | Get-NsxLogicalRouterRouting | Set-NsxLogicalRouterRouting -EnableBgpRouteRedistribution -confirm:$false
Get-NsxLogicalRouter DLR-01 | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterRedistributionRule -FromConnected -Learner bgp -confirm:$false
Get-NsxLogicalRouter DLR-01 | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterBgpNeighbour -IpAddress 172.16.0.1 -RemoteAS 65001 -ForwardingAddress 172.16.0.10 -confirm:$false -ProtocolAddress 172.16.0.11

#Configure ESG For Routing: 
Get-NsxEdge DC-Edge-01 
Get-NsxEdge DC-Edge-01 | Get-NsxEdgeRouting | Set-NsxEdgeRouting -EnableBgp -RouterId 192.168.100.3 -LocalAS 65001 -confirm:$false 
Get-NsxEdge DC-Edge-01 | Get-NsxEdgeRouting | Set-NsxEdgeRouting -EnableBgpRouteRedistribution -confirm:$false
Get-NsxEdge DC-Edge-01 | Get-NsxEdgeRouting | Set-NsxEdgeBgp -GracefulRestart -DefaultOriginate -confirm:$false
Get-NsxEdge DC-Edge-01 | Get-NsxEdgeRouting | New-NsxEdgeRedistributionRule -Learner bgp -FromConnected -FromStatic -Action permit -confirm:$false
Get-NsxEdge DC-Edge-01 | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -IpAddress 172.16.0.11 -RemoteAS 65001 -confirm:$false
Get-NsxEdge DC-Edge-01 | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -IpAddress 192.168.100.1 -RemoteAS 65002 -confirm:$false

#Configure Load Balancer
Get-NsxEdge LB-01a
Get-NsxEdge LB-01a | Get-NsxLoadBalancer | Set-NsxLoadBalancer -enabled
Get-NsxEdge LB-01a | Get-NsxEdgeInterface -name LB-Uplink | Set-NsxEdgeInterface -Name LB-Uplink -type uplink -ConnectedTo (Get-NsxLogicalSwitch WEB-LS) -PrimaryAddress "172.16.10.10" -SubnetPrefixLength 24 -confirm:$false
$Monitor = Get-NsxEdge LB-01a | Get-NsxLoadBalancer | Get-NsxLoadBalancerMonitor default_tcp_monitor
$member1 = New-NsxLoadBalancerMemberSpec -Name web01a -IpAddress 172.16.10.11 -port 443
$member2 = New-NsxLoadBalancerMemberSpec -Name web02a -IpAddress 172.16.10.12 -port 443
$Pool = Get-NsxEdge LB-01a | Get-NSXLoadBalancer | New-NsxLoadBalancerPool -Name DB-App-Web-Pool -Algorithm round-robin -Monitor $Monitor -MemberSpec $member1,$member2
$profile = Get-NsxEdge LB-01a | Get-NsxLoadBalancer | New-NsxLoadBalancerApplicationProfile -name DB-App-Profile -Type HTTPS -SslPassthrough
Get-NsxEdge LB-01a | Get-NSXLoadBalancer | Add-NsxLoadBalancerVip -name DB-App-VIP -ipaddress 172.16.10.10 -Protocol HTTPS -Port 443 -ApplicationProfile $profile -DefaultPool $Pool 

# Setting up the Arista Network

configure terminal

vlan 10
   name Management

vlan 20
   name Storage

vlan 30
   name VM-Traffic

interface Vlan10
   description Proxmox Management
   ip address 10.10.10.1/24
   no shutdown

interface Vlan20
   description Storage Network
   ip address 10.10.20.1/24
   no shutdown

interface Vlan30
   description VM Traffic
   ip address 10.10.30.1/24
   no shutdown

ip routing

interface Port-Channel1
   description Node1-Bond
   switchport mode trunk
   switchport trunk allowed vlan 10,20,30
   switchport trunk native vlan 10
   no shutdown

interface Ethernet1
   description Node1-NIC1
   channel-group 1 mode active
   no shutdown

interface Ethernet2
   description Node1-NIC2
   channel-group 1 mode active
   no shutdown

interface Port-Channel2
   description Node2-Bond
   switchport mode trunk
   switchport trunk allowed vlan 10,20,30
   switchport trunk native vlan 10
   no shutdown

interface Ethernet3
   description Node2-NIC1
   channel-group 2 mode active
   no shutdown

interface Ethernet4
   description Node2-NIC2
   channel-group 2 mode active
   no shutdown

interface Port-Channel3
   description Node3-Bond
   switchport mode trunk
   switchport trunk allowed vlan 10,20,30
   switchport trunk native vlan 10
   no shutdown

interface Ethernet5
   description Node3-NIC1
   channel-group 3 mode active
   no shutdown

interface Ethernet6
   description Node3-NIC2
   channel-group 3 mode active
   no shutdown

interface Port-Channel4
   description Node4-Bond
   switchport mode trunk
   switchport trunk allowed vlan 10,20,30
   switchport trunk native vlan 10
   no shutdown

interface Ethernet7
   description Node4-NIC1
   channel-group 4 mode active
   no shutdown

interface Ethernet8
   description Node4-NIC2
   channel-group 4 mode active
   no shutdown

interface Port-Channel5
   description Node5-Bond
   switchport mode trunk
   switchport trunk allowed vlan 10,20,30
   switchport trunk native vlan 10
   no shutdown

interface Ethernet9
   description Node5-NIC1
   channel-group 5 mode active
   no shutdown

interface Ethernet10
   description Node5-NIC2
   channel-group 5 mode active
   no shutdown

interface Port-Channel6
   description Node6-Bond
   switchport mode trunk
   switchport trunk allowed vlan 10,20,30
   switchport trunk native vlan 10
   no shutdown

interface Ethernet11
   description Node6-NIC1
   channel-group 6 mode active
   no shutdown

interface Ethernet12
   description Node6-NIC2
   channel-group 6 mode active
   no shutdown

interface Port-Channel7
   description Node7-Bond
   switchport mode trunk
   switchport trunk allowed vlan 10,20,30
   switchport trunk native vlan 10
   no shutdown

interface Ethernet13
   description Node7-NIC1
   channel-group 7 mode active
   no shutdown

interface Ethernet14
   description Node7-NIC2
   channel-group 7 mode active
   no shutdown
   
write memory
exit

## Now we have constructed the arista to be ready for all 10g connections, it will bond those connections together acting as a 20Gb connection, and adds redundancy




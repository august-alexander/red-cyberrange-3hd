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


# Supermicro to Arista 20G LACP Bond Setup

Configure a dual 10G bonded (LACP) connection from Supermicro servers to an Arista switch with trunked VLANs for a Proxmox cyber range environment.

## Prerequisites

- Supermicro server with dual-port 10G NIC (e.g., `ens1f0` / `ens1f1`)
- Arista switch with LACP port-channels already configured ([see Arista config](#arista-switch-config-reference))
- Ubuntu/Debian-based OS (tested on Ubuntu with kernel 6.17)
- Two SFP+ cables per server connected to the correct Arista port-channel pair

## Network Overview

```
┌─────────────────────────────────────────────────────┐
│                   ARISTA SWITCH                      │
│                                                      │
│  Po1 (Et1+Et2)  Po2 (Et3+Et4)  Po3 (Et5+Et6) ...  │
│  LACP 20G bond   LACP 20G bond   LACP 20G bond      │
│                                                      │
│  VLAN 10: Management  (10.10.10.0/24)               │
│  VLAN 20: Storage     (10.10.20.0/24)               │
│  VLAN 30: VM Traffic  (10.10.30.0/24)               │
└──────┬──────────────────┬──────────────────┬────────┘
       │                  │                  │
   ┌───┴───┐          ┌───┴───┐          ┌───┴───┐
   │Node 1 │          │Node 2 │          │Node 3 │
   │ .21   │          │ .22   │          │ .23   │
   └───────┘          └───────┘          └───────┘
```

Each server also has a 1G onboard NIC on the home network (192.168.x.x) for internet access.

## Step 1: Identify 10G NICs

```bash
ip link show
```

Look for your 10G interfaces. In our case: `ens1f0` and `ens1f1`. Confirm speed:

```bash
ethtool ens1f0 | grep Speed
ethtool ens1f1 | grep Speed
```

Both should report `10000Mb/s`.

> **Note:** Your NIC names may differ. Common names include `enp3s0f0`/`enp3s0f1` or similar. The `altname` field in `ip link show` output can help identify them.

## Step 2: Install Bonding Support

```bash
sudo apt install ifenslave -y
sudo modprobe bonding
echo "bonding" | sudo tee -a /etc/modules
```

> **Tip:** Don't use `sudo echo "bonding" >> /etc/modules` — the redirect runs as your user, not root. Use `tee` instead.

## Step 3: Configure Network Interfaces

Back up the existing config:

```bash
sudo cp /etc/network/interfaces /etc/network/interfaces.bak
```

Edit the config:

```bash
sudo nano /etc/network/interfaces
```

Paste the following, adjusting NIC names and IP addresses per node:

```
source /etc/network/interfaces.d/*

# Loopback
auto lo
iface lo inet loopback

# 1G NIC - Internet
auto eno1
iface eno1 inet dhcp

# 10G NICs
auto ens1f0
iface ens1f0 inet manual
    bond-master bond0

auto ens1f1
iface ens1f1 inet manual
    bond-master bond0

# 10G Bond (LACP to Arista)
auto bond0
iface bond0 inet manual
    bond-slaves none
    bond-miimon 100
    bond-mode 802.3ad
    bond-xmit-hash-policy layer3+4

# VLAN 10 - Management
auto vmbr0
iface vmbr0 inet static
    address 10.10.10.X/24
    gateway 10.10.10.1
    bridge-ports bond0.10
    bridge-stp off
    bridge-fd 0

# VLAN 20 - Storage
auto vmbr1
iface vmbr1 inet static
    address 10.10.20.X/24
    bridge-ports bond0.20
    bridge-stp off
    bridge-fd 0

# VLAN 30 - VM Traffic
auto vmbr2
iface vmbr2 inet static
    address 10.10.30.X/24
    bridge-ports bond0.30
    bridge-stp off
    bridge-fd 0
```

### Per-Node IP Addresses

| Node | VLAN 10 (Mgmt) | VLAN 20 (Storage) | VLAN 30 (VMs) | Arista Ports |
|------|-----------------|-------------------|----------------|--------------|
| 1    | 10.10.10.21     | 10.10.20.21       | 10.10.30.21    | Et1 + Et2    |
| 2    | 10.10.10.22     | 10.10.20.22       | 10.10.30.22    | Et3 + Et4    |
| 3    | 10.10.10.23     | 10.10.20.23       | 10.10.30.23    | Et5 + Et6    |
| 4    | 10.10.10.24     | 10.10.20.24       | 10.10.30.24    | Et7 + Et8    |
| 5    | 10.10.10.25     | 10.10.20.25       | 10.10.30.25    | Et9 + Et10   |
| 6    | 10.10.10.26     | 10.10.20.26       | 10.10.30.26    | Et11 + Et12  |
| 7    | 10.10.10.27     | 10.10.20.27       | 10.10.30.27    | Et13 + Et14  |

### Important: `bond-slaves none`

The slave interfaces declare their master via `bond-master bond0`. The bond itself uses `bond-slaves none`. This prevents a boot race condition where the bond comes up before the slaves are added, causing LACP negotiation to fail.

## Step 4: Fix Slow Boot (Optional but Recommended)

The `systemd-networkd-wait-online.service` waits for all interfaces to be fully online before continuing boot, which adds significant delay when bonding and VLANs are involved.

```bash
sudo systemctl disable systemd-networkd-wait-online.service
```

## Step 5: Reboot and Verify

```bash
sudo reboot
```

### Verify Bond Status (Server Side)

```bash
cat /proc/net/bonding/bond0
```

Expected output:

```
Bonding Mode: IEEE 802.3ad Dynamic link aggregation
Transmit Hash Policy: layer3+4 (1)
MII Status: up

802.3ad info
LACP active: on

Slave Interface: ens1f0
MII Status: up
Speed: 10000 Mbps
Duplex: full
Aggregator ID: 1

Slave Interface: ens1f1
MII Status: up
Speed: 10000 Mbps
Duplex: full
Aggregator ID: 1
```

Both slaves should be `up` at `10000 Mbps` with the same `Aggregator ID`.

### Verify Bond Status (Arista Side)

```
show port-channel summary
```

Expected output for a connected node:

```
Port-Channel       Protocol    Ports
------------------ -------------- ------------------
Po1(U)             LACP(a)     Et1(PG+) Et2(PG+)
```

- `(U)` = In Use
- `(PG+)` = Bundled, Aggregable, In-Sync

Also useful:

```
show lacp interface
```

## Troubleshooting

### Bond is created but MII Status is down

The bond came up before slaves were added (race condition). Fix manually:

```bash
sudo ip link set bond0 down
sudo ip link set ens1f0 down
sudo ip link set ens1f1 down
sudo ifenslave bond0 ens1f0 ens1f1
sudo ip link set bond0 up
```

Then ensure your `/etc/network/interfaces` uses the `bond-master` pattern (slaves declare their master) with `bond-slaves none` on the bond itself.

### LACP not negotiating

Check that both cables from the same server go into the correct Arista port-channel pair. If Node 1's NICs accidentally plug into Et1 and Et3, the LAG breaks because those ports belong to different port-channels.

```
show port-channel summary
```

Look for members showing `(D)` (Down) or `(i)` (incompatible).

### Permission denied on /etc/modules

Use `tee` instead of redirect:

```bash
echo "bonding" | sudo tee -a /etc/modules
```

## Arista Switch Config Reference

For reference, here is the corresponding Arista-side configuration that pairs with this server setup:

```
configure terminal

vlan 10
   name Management
vlan 20
   name Storage
vlan 30
   name VM-Traffic

ip routing

interface Vlan10
   ip address 10.10.10.1/24
   no shutdown

interface Vlan20
   ip address 10.10.20.1/24
   no shutdown

interface Vlan30
   ip address 10.10.30.1/24
   no shutdown

! Repeat for each node pair (example: Node 1)
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

! Node 2: Port-Channel2, Et3+Et4
! Node 3: Port-Channel3, Et5+Et6
! ... and so on through Node 7: Port-Channel7, Et13+Et14
```

## Cabling Reference

**Rule:** Both NICs from the same server must go into the same port-channel pair.

| Server | Arista Ports | Port-Channel |
|--------|-------------|--------------|
| Node 1 | Et1 + Et2   | Po1          |
| Node 2 | Et3 + Et4   | Po2          |
| Node 3 | Et5 + Et6   | Po3          |
| Node 4 | Et7 + Et8   | Po4          |
| Node 5 | Et9 + Et10  | Po5          |
| Node 6 | Et11 + Et12 | Po6          |
| Node 7 | Et13 + Et14 | Po7          |

**Tip:** Label your cables or be consistent — left NIC to odd port, right NIC to even port.




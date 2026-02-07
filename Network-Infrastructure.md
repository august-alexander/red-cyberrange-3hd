# Cyber Range Network Infrastructure Journal

## Overview

This journal documents the process of building a 7-node cyber range with enterprise-grade networking. The infrastructure uses an Arista switch with LACP bonding to provide 20Gbps aggregate bandwidth to each Supermicro server.

**Philosophy:** We're building from the ground up - Layer 1 physical connectivity first, with static IPs on a single flat network. Proxmox will handle VLANs and virtualization on top of this foundation later.

## Network Topology

```
                    ARISTA SWITCH
                   (10.10.10.1/24)
                         |
    ┌────────┬───────────┼───────────┬────────┐
    |        |           |           |        |
  Po1(20G) Po2(20G)   Po3(20G)    Po4(20G) Po5(20G) Po6(20G) Po7(20G)
    |        |           |           |        |
  red1     red2        red3        red4     red5     red6     red7
 .11       .12         .13         .14      .15      .16      .17
```

### IP Addressing Scheme

**Base Network:** 10.10.10.0/24

| Device | IP Address    | Hostname | Purpose           |
|--------|---------------|----------|-------------------|
| Arista | 10.10.10.1    | -        | Switch management |
| Node 1 | 10.10.10.11   | red1     | Cyber range node  |
| Node 2 | 10.10.10.12   | red2     | Cyber range node  |
| Node 3 | 10.10.10.13   | red3     | Cyber range node  |
| Node 4 | 10.10.10.14   | red4     | Cyber range node  |
| Node 5 | 10.10.10.15   | red5     | Cyber range node  |
| Node 6 | 10.10.10.16   | red6     | Cyber range node  |
| Node 7 | 10.10.10.17   | red7     | Cyber range node  |

### Physical Connections

Each server has:
- 2x 10GbE NICs bonded via LACP (802.3ad) = 20Gbps aggregate
- 1x 1GbE NIC for internet access (DHCP on home network)

| Server | NIC Interfaces    | Arista Ports  | Port-Channel |
|--------|-------------------|---------------|--------------|
| red1   | ens1f0, ens1f1    | Et1 + Et2     | Po1          |
| red2   | ens3, ens3d1      | Et3 + Et4     | Po2          |
| red3   | TBD               | Et5 + Et6     | Po3          |
| red4   | TBD               | Et7 + Et8     | Po4          |
| red5   | TBD               | Et9 + Et10    | Po5          |
| red6   | TBD               | Et11 + Et12   | Po6          |
| red7   | TBD               | Et13 + Et14   | Po7          |

---

## Part 1: Arista Switch Configuration

### Initial Cleanup

We had old VLAN configurations from previous attempts that needed removal. Start fresh:

```bash
enable
configure terminal

# Remove old VLANs
no interface Vlan10
no vlan 10
no vlan 20
no vlan 30

# Remove old port-channels
no interface Port-Channel1
no interface Port-Channel2
no interface Port-Channel3
no interface Port-Channel4
no interface Port-Channel5
no interface Port-Channel6
no interface Port-Channel7

# Reset Ethernet interfaces to defaults (if needed)
default interface Ethernet1-14

write memory
```

### Configure VLAN 1 Management Interface

The switch needs an IP address on VLAN 1 to communicate with the servers:

```bash
configure terminal

interface Vlan1
   ip address 10.10.10.1/24
   no shutdown

write memory
```

### Configure Port-Channels with LACP

Set up all seven port-channels for the seven servers:

```bash
configure terminal

# Port-Channel 1 for red1 (Ethernet 1-2)
interface Port-Channel1
   description red1-bond
   switchport mode access
   switchport access vlan 1
   no shutdown

interface Ethernet1-2
   description red1-links
   channel-group 1 mode active
   lacp timer fast
   no shutdown

# Port-Channel 2 for red2 (Ethernet 3-4)
interface Port-Channel2
   description red2-bond
   switchport mode access
   switchport access vlan 1
   no shutdown

interface Ethernet3-4
   description red2-links
   channel-group 2 mode active
   lacp timer fast
   no shutdown

# Port-Channel 3 for red3 (Ethernet 5-6)
interface Port-Channel3
   description red3-bond
   switchport mode access
   switchport access vlan 1
   no shutdown

interface Ethernet5-6
   description red3-links
   channel-group 3 mode active
   lacp timer fast
   no shutdown

# Port-Channel 4 for red4 (Ethernet 7-8)
interface Port-Channel4
   description red4-bond
   switchport mode access
   switchport access vlan 1
   no shutdown

interface Ethernet7-8
   description red4-links
   channel-group 4 mode active
   lacp timer fast
   no shutdown

# Port-Channel 5 for red5 (Ethernet 9-10)
interface Port-Channel5
   description red5-bond
   switchport mode access
   switchport access vlan 1
   no shutdown

interface Ethernet9-10
   description red5-links
   channel-group 5 mode active
   lacp timer fast
   no shutdown

# Port-Channel 6 for red6 (Ethernet 11-12)
interface Port-Channel6
   description red6-bond
   switchport mode access
   switchport access vlan 1
   no shutdown

interface Ethernet11-12
   description red6-links
   channel-group 6 mode active
   lacp timer fast
   no shutdown

# Port-Channel 7 for red7 (Ethernet 13-14)
interface Port-Channel7
   description red7-bond
   switchport mode access
   switchport access vlan 1
   no shutdown

interface Ethernet13-14
   description red7-links
   channel-group 7 mode active
   lacp timer fast
   no shutdown

write memory
exit
```

### Verify Arista Configuration

```bash
# Check VLAN 1 interface
show ip interface brief

# Check port-channel status
show port-channel summary

# Should show all Po1-7 with (D) for down until servers connect
```

**Note on Syntax:** On Arista, the fast LACP timer is `lacp timer fast`, not `lacp rate fast` (which is deprecated).

---

## Part 2: Server Configuration (Example: red1)

### Step 1: Identify Network Interfaces

Each Supermicro server may have different NIC naming. Check what you have:

```bash
ip link show
```

**red1 has:** `ens1f0` and `ens1f1` (10GbE interfaces)  
**red2 has:** `ens3` and `ens3d1` (10GbE interfaces)

You must identify the correct interface names for each server before configuring.

### Step 2: Install Bonding Support

```bash
sudo apt-get update
sudo apt-get install ifenslave -y
```

### Step 3: Configure Network Interfaces

**For red1** (using `ens1f0` and `ens1f1`):

Back up existing config:
```bash
sudo cp /etc/network/interfaces /etc/network/interfaces.backup
```

Edit the interfaces file:
```bash
sudo nano /etc/network/interfaces
```

**Configuration for red1:**

```
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:

source /etc/network/interfaces.d/*

# Loopback
auto lo
iface lo inet loopback

# 1G NIC - Internet
auto eno1
iface eno1 inet dhcp

# 10G Bond (LACP to Arista)
auto bond0
iface bond0 inet static
    address 10.10.10.11
    netmask 255.255.255.0
    gateway 10.10.10.1
    bond-slaves ens1f0 ens1f1
    bond-mode 802.3ad
    bond-miimon 100
    bond-lacp-rate fast
    bond-xmit-hash-policy layer3+4

# 10G NICs - Bonded
auto ens1f0
iface ens1f0 inet manual
    bond-master bond0

auto ens1f1
iface ens1f1 inet manual
    bond-master bond0
```

**Key Configuration Details:**
- `bond-mode 802.3ad` - LACP dynamic link aggregation
- `bond-miimon 100` - Link monitoring every 100ms
- `bond-lacp-rate fast` - LACP packets every 1 second (faster failover)
- `bond-xmit-hash-policy layer3+4` - Load balance based on IP + port

### Step 4: Reboot and Verify

```bash
sudo reboot
```

After reboot, verify bond status:

```bash
cat /proc/net/bonding/bond0
```

**Expected output:**
```
Ethernet Channel Bonding Driver: v6.17.0-12-generic

Bonding Mode: IEEE 802.3ad Dynamic link aggregation
Transmit Hash Policy: layer3+4 (1)
MII Status: up
MII Polling Interval (ms): 100

802.3ad info
LACP active: on
LACP rate: fast
Min links: 0
Aggregator selection policy (ad_select): stable

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

**What to look for:**
- `MII Status: up` (bond is operational)
- Both slaves show `Speed: 10000 Mbps`
- Both slaves have same `Aggregator ID` (means they're bundled together)

### Step 5: Test Connectivity

```bash
# Ping the Arista switch
ping 10.10.10.1

# Check IP assignment
ip a show bond0
```

### Step 6: Verify on Arista Side

From the Arista switch:

```bash
# Check port-channel status
show port-channel summary

# Expected for red1:
# Po1(U)    LACP(a)    Et1(PG+) Et2(PG+)

# Check LACP neighbor details
show lacp neighbor

# Verify ARP table
show ip arp | include 10.10.10.11

# Test ping from Arista
ping 10.10.10.11
```

**Port-Channel Status Codes:**
- `(U)` = In Use / Up
- `(PG+)` = Port in port-channel, In-Sync, Collecting/Distributing

---

## Part 3: Configuring Remaining Servers (red2-red7)

### Process for Each Server

1. **SSH into the server**
2. **Identify interface names:** `ip link show`
3. **Edit `/etc/network/interfaces`** with the correct interface names and IP
4. **Reboot**
5. **Verify bond and connectivity**

### Example: red2 Configuration

**red2 interface names:** `ens3` and `ens3d1`

```
# Loopback
auto lo
iface lo inet loopback

# 1G NIC - Internet
auto eno1
iface eno1 inet dhcp

# 10G Bond (LACP to Arista)
auto bond0
iface bond0 inet static
    address 10.10.10.12
    netmask 255.255.255.0
    gateway 10.10.10.1
    bond-slaves ens3 ens3d1
    bond-mode 802.3ad
    bond-miimon 100
    bond-lacp-rate fast
    bond-xmit-hash-policy layer3+4

# 10G NICs - Bonded
auto ens3
iface ens3 inet manual
    bond-master bond0

auto ens3d1
iface ens3d1 inet manual
    bond-master bond0
```

**Note:** Only change:
- IP address (10.10.10.12 for red2, .13 for red3, etc.)
- Interface names (`bond-slaves` and interface definitions)

### Quick Reference - IP Assignments

| Server | IP Address   | Port-Channel | Arista Ports |
|--------|--------------|--------------|--------------|
| red1   | 10.10.10.11  | Po1          | Et1 + Et2    |
| red2   | 10.10.10.12  | Po2          | Et3 + Et4    |
| red3   | 10.10.10.13  | Po3          | Et5 + Et6    |
| red4   | 10.10.10.14  | Po4          | Et7 + Et8    |
| red5   | 10.10.10.15  | Po5          | Et9 + Et10   |
| red6   | 10.10.10.16  | Po6          | Et11 + Et12  |
| red7   | 10.10.10.17  | Po7          | Et13 + Et14  |

---

## Troubleshooting

### Bond Shows "MII Status: down"

**Symptom:** Bond interface exists but shows as down, or "Waiting for a slave to join bond0"

**Causes:**
- Physical links are down
- LACP not negotiating
- Interfaces brought up in wrong order

**Solutions:**

```bash
# Check physical link status
ethtool ens1f0 | grep "Link detected"
ethtool ens1f1 | grep "Link detected"

# Manually restart bond
sudo ip link set bond0 down
sudo ip link set ens1f0 down
sudo ip link set ens1f1 down
sudo ip link set ens1f0 up
sudo ip link set ens1f1 up
sudo ip link set bond0 up

# Or just reboot for clean state
sudo reboot
```

### Wrong Interface Names

**Symptom:** Configuration fails or interfaces don't exist

**Solution:** Always run `ip link show` first to identify actual interface names. They vary by server:
- red1: `ens1f0`, `ens1f1`
- red2: `ens3`, `ens3d1`
- Others: May be `enp*`, `eno*`, etc.

### LACP Not Negotiating on Arista

**Symptom:** Port-channel shows `(D)` for down or `(i)` for incompatible

**Check:**
```bash
show port-channel 1 detail
show lacp neighbor
```

**Common causes:**
- Cables plugged into wrong ports (e.g., red1's two cables go into Et1 and Et3 instead of Et1 and Et2)
- Server-side bond not configured properly
- Physical cable issues

### Can't Ping Gateway (10.10.10.1)

**Checks:**

On server:
```bash
# Verify IP is assigned
ip a show bond0

# Verify routing
ip route

# Check if bond is actually up
cat /proc/net/bonding/bond0
```

On Arista:
```bash
# Verify Vlan1 interface is up
show ip interface brief

# Check if server's MAC is learned
show mac address-table

# Check ARP
show ip arp
```

---

## Next Steps

Once all seven servers have working bonded connections and can ping each other:

1. **Install Proxmox** on each server
2. **Configure VLANs** in Proxmox for network segmentation:
   - VLAN 10: Management
   - VLAN 20: Storage  
   - VLAN 30: VM Traffic
3. **Build cyber range environments** on top of the Proxmox cluster
4. **Implement Grafana Cloud monitoring** for infrastructure visibility

The current base layer provides a solid foundation:
- 20Gbps per server (dual 10G bonded)
- Redundancy via LACP (automatic failover if one link fails)
- Simple flat network for easy management
- Ready for virtualization layer on top

---

## Lessons Learned

### What Worked Well
- Starting with a clean configuration (removing all old VLANs and port-channels)
- Building Layer 1 first before adding complexity
- Using access mode on port-channels (not trunk) since VLANs will be handled by Proxmox
- Testing connectivity at each step before moving to the next server

### Common Mistakes to Avoid
- Don't assume interface names are consistent across servers - always check with `ip link show`
- On Arista, use `lacp timer fast`, not `lacp rate fast` (deprecated)
- Don't configure VLANs at the base layer - let Proxmox handle that
- Always reboot servers after network configuration changes for clean state
- Label your cables! It's easy to plug servers into wrong port pairs

### Why This Approach
We deliberately kept the base layer simple: static IPs on VLAN 1, LACP bonding for bandwidth and redundancy, and that's it. This gives us:
- Easy troubleshooting (fewer moving parts)
- Clear separation of concerns (physical layer vs. virtual layer)
- Flexibility for Proxmox to implement its own VLAN strategy
- A solid foundation that "just works"

The cyber range complexity comes later in the virtualization layer - not at the physical network layer.

---

## Verification Commands Quick Reference

### Server Side
```bash
# Check bond status
cat /proc/net/bonding/bond0

# Check IP configuration
ip a show bond0

# Test connectivity
ping 10.10.10.1
ping 10.10.10.12  # Another server

# Check physical link status
ethtool ens1f0 | grep "Link detected"
```

### Arista Side
```bash
# Port-channel summary
show port-channel summary

# Detailed port-channel info
show port-channel 1 detail

# LACP neighbor information
show lacp neighbor

# ARP table
show ip arp

# MAC address table
show mac address-table

# Interface status
show interfaces status

# Ping server
ping 10.10.10.11
```

---

**Document Status:** Living document - will be updated as additional servers (red3-red7) are configured and as the cyber range evolves.

**Last Updated:** February 7, 2026

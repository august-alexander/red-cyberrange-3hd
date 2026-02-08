# Proxmox Cyber Range Cluster - Configuration Blueprint

## Overview

This blueprint documents the configuration of a 7-node Proxmox cluster for a cyber range environment with complete network isolation between management and operational networks.

**Current Status:** 3 nodes configured (red1, red2, red3)  
**Pending:** 4 nodes to be added (red4, red5, red6, red7)

## Architecture Goals

1. **Management Network (Home - 192.168.1.x):** Proxmox web UI access, cluster communication, internet access
2. **Operational Network (Arista - 10.10.10.x):** All VM traffic, storage (Ceph), VM migration - completely isolated from home network
3. **High Performance:** 40Gbps bonded connections via Arista switch for all operational traffic
4. **Security:** VMs never touch the home network, only exist on isolated Arista network

---

## Network Topology

```
                    HOME NETWORK (192.168.1.0/24)
                            |
        ┌──────────┬────────┼────────┬──────────┐
        │          │        │        │          │
      eno1       eno1     eno1     eno1       eno1  (1G internet)
        │          │        │        │          │
      red1       red2     red3     red4  ...  red7
        │          │        │        │          │
      bond0      bond0    bond0    bond0      bond0 (40G bonded)
        │          │        │        │          │
        └──────────┴────────┴────────┴──────────┘
                            |
                    ARISTA SWITCH
                   (10.10.10.1/24)
                            |
              OPERATIONAL NETWORK (10.10.10.0/24)
                            |
            ┌───────────────┼───────────────┐
            │               │               │
         VMs/VLANs      Ceph Storage    VM Migration
```

---

## IP Address Allocation

### Management Network (Home - 192.168.1.x)

| Node  | Interface | IP Address      | Purpose                    |
|-------|-----------|-----------------|----------------------------|
| red1  | eno1      | 192.168.1.171   | Proxmox Web UI, Corosync  |
| red2  | eno1      | 192.168.1.172   | Proxmox Web UI, Corosync  |
| red3  | eno1      | 192.168.1.173   | Proxmox Web UI, Corosync  |
| red4  | eno1      | 192.168.1.174   | Proxmox Web UI, Corosync  |
| red5  | eno1      | 192.168.1.175   | Proxmox Web UI, Corosync  |
| red6  | eno1      | 192.168.1.176   | Proxmox Web UI, Corosync  |
| red7  | eno1      | 192.168.1.177   | Proxmox Web UI, Corosync  |

**Gateway:** 192.168.1.1  
**DNS:** 8.8.8.8

### Operational Network (Arista - 10.10.10.x)

| Node   | Interface | IP Address    | Arista Ports    | Bond Speed |
|--------|-----------|---------------|-----------------|------------|
| red1   | bond0     | 10.10.10.11   | Et1 + Et2       | 20G        |
| red2   | bond0     | 10.10.10.12   | Et3 + Et4       | 20G        |
| red3   | bond0     | 10.10.10.13   | Et5 + Et6       | 20G        |
| red4   | bond0     | 10.10.10.14   | Et7 + Et8       | 20G        |
| red5   | bond0     | 10.10.10.15   | Et9 + Et10      | 20G        |
| red6   | bond0     | 10.10.10.16   | Et11 + Et12     | 20G        |
| red7   | bond0     | 10.10.10.17   | Et25-28         | 40G        |

**Gateway:** None (isolated network)  
**Arista Switch:** 10.10.10.1

---

## Part 1: Configure Existing Nodes (red1, red2, red3)

These steps must be completed on red1, red2, and red3 before adding new nodes.

### Step 1: Create Linux Bridge on bond0

This bridge allows VMs to connect to the Arista network.

**On each node (red1, red2, red3):**

1. Access Proxmox Web UI: `https://192.168.1.17X:8006`
2. Click on node name (e.g., **red1**) in left panel
3. Go to **System** → **Network**
4. Click **Create** → **Linux Bridge**

**Configuration:**
- **Name:** `vmbr0`
- **Bridge ports:** `bond0`
- **IPv4/CIDR:** None (bond0 already has the IP)
- **Autostart:** Yes
- **Comment:** `VM Bridge - Arista Network`

5. Click **Create**
6. Click **Apply Configuration** (top of page)

**Expected Result:**
```
bond0 (10.10.10.11/24) - LACP bond
  └── vmbr0 (bridge) - VMs attach here
```

**Verification:**
```bash
# SSH into node or use Shell in web UI
ip a show vmbr0
# Should show vmbr0 UP with bond0 as member

brctl show
# Should show vmbr0 with bond0 as interface
```

### Step 2: Verify Cluster Network Configuration

Check that cluster communication (corosync) is using the home network, not the Arista network.

**On any node:**
```bash
cat /etc/pve/corosync.conf
```

**Expected output:**
```
nodelist {
  node {
    name: red1
    nodeid: 1
    quorum_votes: 1
    ring0_addr: 192.168.1.171  # <-- Home network
  }
  node {
    name: red2
    nodeid: 2
    quorum_votes: 1
    ring0_addr: 192.168.1.172  # <-- Home network
  }
  node {
    name: red3
    nodeid: 3
    quorum_votes: 1
    ring0_addr: 192.168.1.173  # <-- Home network
  }
}
```

**If corosync is using 10.10.10.x addresses:** You need to reconfigure the cluster to use the home network for cluster communication. This is important because corosync is lightweight and you want to keep management separate from heavy storage/VM traffic.

**To fix (if needed):**
```bash
# This is complex - contact me if this is wrong
pvecm updatecerts --force
```

### Step 3: Install Ceph on Cluster

Ceph provides distributed storage across all nodes using the high-speed Arista network.

**Install Ceph on each node:**

1. Click on **red1** in left panel
2. Go to **Ceph** section
3. Click **Install Ceph**
4. Select Ceph version (use default, likely Reef or Quincy)
5. Click **Start Installation**
6. Wait for completion

Repeat for red2 and red3.

**Verification:**
```bash
ceph --version
# Should show installed version
```

### Step 4: Configure Ceph Network

This ensures all Ceph traffic uses the Arista network (10.10.10.x).

**On red1 (via web UI):**

1. Click **red1** → **Ceph** → **Configuration**
2. Click **Edit** or configure initial settings:
   - **Public Network:** `10.10.10.0/24`
   - **Cluster Network:** `10.10.10.0/24`
3. Save configuration

**Verification:**
```bash
cat /etc/pve/ceph.conf
```

Should contain:
```
[global]
public_network = 10.10.10.0/24
cluster_network = 10.10.10.0/24
```

### Step 5: Create Ceph Monitors

Ceph monitors manage the cluster state. You need 3 for quorum.

**Create monitor on red1:**

1. **red1** → **Ceph** → **Monitor**
2. Click **Create**
3. Monitor will be created on red1 using 10.10.10.11

**Create monitor on red2:**

1. **red2** → **Ceph** → **Monitor**
2. Click **Create**

**Create monitor on red3:**

1. **red3** → **Ceph** → **Monitor**
2. Click **Create**

**Verification:**
```bash
ceph -s
# Should show:
#   cluster: healthy
#   mon: 3 daemons
```

### Step 6: Create Ceph Manager

Ceph managers handle administrative tasks and provide the dashboard.

**On red1:**
1. **red1** → **Ceph** → **Manager**
2. Click **Create**

Repeat on red2 and red3.

**Verification:**
```bash
ceph -s
# Should show:
#   mgr: red1(active), standbys: red2, red3
```

### Step 7: Add Ceph OSDs (Storage Disks)

OSDs are the actual storage disks that Ceph uses.

**For each node:**

1. Click on node → **Ceph** → **OSD**
2. Click **Create: OSD**
3. Select unused disk (e.g., `/dev/sdb`, `/dev/sdc`, etc.)
4. Click **Create**

**Repeat for all available disks on all nodes.**

**Important:** 
- Don't use `/dev/sda` (that's your Proxmox boot disk)
- Ceph will format and take over these disks completely
- More disks = more storage and better performance

**Verification:**
```bash
ceph osd tree
# Should show all OSDs from all nodes

ceph -s
# Should show:
#   osd: X osds: X up, X in
```

### Step 8: Create Ceph Pool

Pools are logical storage containers in Ceph.

**On any node:**

1. **Datacenter** → **Ceph** → **Pools**
2. Click **Create**
3. **Name:** `cyberrange-vms`
4. **PG Num:** Calculate based on OSDs (use Proxmox calculator or default)
5. **Min. Size:** 2 (minimum replicas)
6. **Size:** 3 (total replicas across cluster)
7. Click **Create**

**Verification:**
```bash
ceph osd pool ls
# Should show: cyberrange-vms

ceph df
# Shows storage usage
```

### Step 9: Add Ceph Storage to Proxmox

Make the Ceph pool available for VM storage.

**On Datacenter level:**

1. **Datacenter** → **Storage** → **Add** → **RBD**
2. **ID:** `ceph-vms`
3. **Pool:** `cyberrange-vms`
4. **Nodes:** Select all (red1, red2, red3)
5. **Content:** Select `Disk image`, `Container`
6. Click **Add**

**Result:** All nodes can now create VMs on shared Ceph storage.

### Step 10: Configure VM Migration Settings

Ensure VM migration uses the Arista network.

**On each node:**

Edit `/etc/pve/datacenter.cfg`:

```bash
nano /etc/pve/datacenter.cfg
```

Add or modify:
```
migration: secure,network=10.10.10.0/24
```

This forces live migration to use the 10.10.10.x network (40G Arista) instead of the 1G home network.

**Verification:**
- Try migrating a VM between nodes
- Monitor network traffic on bond0 - should see high throughput

---

## Part 2: Prepare for New Nodes (red4, red5, red6, red7)

### Prerequisites Before Adding New Nodes

**Hardware:**
- Supermicro server with Proxmox installed
- 1G NIC connected to home network (eno1 or similar)
- 2x 10G NICs (or 4x for red7) bonded with LACP to Arista switch
- Storage disks for Ceph OSDs

**Arista Switch:**
- Port-channels 4, 5, 6, 7 configured
- Ports in VLAN 1 access mode
- LACP enabled

**Network:**
- Static IP on home network (192.168.1.174-177)
- Static IP on Arista network (10.10.10.14-17)

### Installation Process for New Nodes

**Step 1: Install Proxmox**

Boot from Proxmox ISO and configure:
- **Management interface:** nic0 (1G home network interface)
- **Hostname:** `red4.local` (or red5, red6, red7)
- **IP address:** `192.168.1.174/24` (increment for each)
- **Gateway:** `192.168.1.1`
- **DNS:** `8.8.8.8`

**Step 2: Configure Bond Interface**

**For red4, red5, red6 (2-port bonds):**

SSH or console into the new node:

```bash
nano /etc/network/interfaces
```

Add configuration (adjust interface names based on actual hardware):

```bash
# 10G Bond (LACP to Arista)
auto bond0
iface bond0 inet static
    address 10.10.10.14/24
    bond-slaves ens1f0 ens1f1
    bond-mode 802.3ad
    bond-miimon 100
    bond-lacp-rate fast
    bond-xmit-hash-policy layer3+4

auto ens1f0
iface ens1f0 inet manual
    bond-master bond0

auto ens1f1
iface ens1f1 inet manual
    bond-master bond0
```

**For red7 (4-port bond):**

```bash
# 10G Bond (LACP to Arista) - 4 ports
auto bond0
iface bond0 inet static
    address 10.10.10.17/24
    bond-slaves ens2f0np0 ens2f1np1 ens2f2np2 ens2f3np3
    bond-mode 802.3ad
    bond-miimon 100
    bond-lacp-rate fast
    bond-xmit-hash-policy layer3+4

auto ens2f0np0
iface ens2f0np0 inet manual
    bond-master bond0

auto ens2f1np1
iface ens2f1np1 inet manual
    bond-master bond0

auto ens2f2np2
iface ens2f2np2 inet manual
    bond-master bond0

auto ens2f3np3
iface ens2f3np3 inet manual
    bond-master bond0
```

Save and apply:
```bash
systemctl restart networking
# Or reboot for clean state
reboot
```

**Verification:**
```bash
cat /proc/net/bonding/bond0
# Should show all slaves active with 10G speed
```

**Step 3: Join Node to Cluster**

**On red1 (existing cluster node):**
1. Click **red1** → **Cluster** → **Join Information**
2. Copy the join information string

**On new node (e.g., red4):**
1. Access web UI: `https://192.168.1.174:8006`
2. Click **Datacenter** → **Cluster** → **Join Cluster**
3. Paste join information
4. Enter red1's root password
5. Click **Join**
6. May show permission errors - **ignore and reboot the new node**
7. After reboot, node should appear in cluster

**Verification:**
```bash
# On red1
pvecm status
# Should show new node count

pvecm nodes
# Should list all nodes including new one
```

**Step 4: Configure Network on New Node**

**Create vmbr0 bridge:**

1. Click new node → **System** → **Network**
2. **Create** → **Linux Bridge**
3. **Name:** `vmbr0`
4. **Bridge ports:** `bond0`
5. **Autostart:** Yes
6. Click **Create** → **Apply Configuration**

**Step 5: Install Ceph on New Node**

1. Click new node → **Ceph** → **Install Ceph**
2. Use same version as existing nodes
3. Wait for installation

**Verification:**
```bash
ceph --version
```

**Step 6: Add Ceph Monitor (if needed)**

For high availability, you can add monitors on additional nodes:

1. Click new node → **Ceph** → **Monitor**
2. Click **Create**

**Note:** You already have 3 monitors (quorum), so this is optional for nodes 4-7.

**Step 7: Add Ceph Manager**

1. Click new node → **Ceph** → **Manager**
2. Click **Create**

**Step 8: Add Ceph OSDs**

1. Click new node → **Ceph** → **OSD**
2. For each available disk:
   - Click **Create: OSD**
   - Select disk
   - Click **Create**

**Verification:**
```bash
ceph osd tree
# Should show new OSDs from new node

ceph -s
# Should show increased OSD count
```

**Step 9: Verify Storage Access**

1. **Datacenter** → **Storage**
2. Verify `ceph-vms` storage is available on new node
3. Try creating a test VM on the new node using Ceph storage

---

## Part 3: VM Configuration for Isolated Network

### Creating VMs on the Arista Network

When creating VMs, ensure they ONLY connect to the Arista network (vmbr0), never to the home network.

**VM Creation Steps:**

1. **Right-click node** → **Create VM**
2. **General:**
   - VM ID: (auto or specify)
   - Name: (your choice)
3. **OS:**
   - ISO image: (upload to Ceph storage first)
4. **System:**
   - Default settings
5. **Disks:**
   - **Storage:** `ceph-vms` (Ceph storage)
   - **Disk size:** As needed
6. **CPU:**
   - As needed
7. **Memory:**
   - As needed
8. **Network:**
   - **Bridge:** `vmbr0` (CRITICAL - this is the Arista network)
   - **VLAN Tag:** (optional, for segmentation)
   - **Model:** VirtIO (best performance)

**IMPORTANT:** Never select any bridge connected to eno1 or the home network. VMs must ONLY use vmbr0.

### VM Network Configuration (Inside VM)

Once VM is created and booted:

**Option 1 - DHCP:**
Set up a DHCP server on the 10.10.10.x network (maybe on a dedicated VM or on your router if it can reach this network)

**Option 2 - Static IP:**
Configure static IP within the 10.10.10.x range:
- IP: `10.10.10.100+` (avoid .1-.20 for infrastructure)
- Netmask: `255.255.255.0`
- Gateway: `10.10.10.1` (if you want internet via Arista) or none (isolated)
- DNS: Your choice

**Result:** VM can communicate with other VMs on the Arista network but has zero access to your home network.

---

## Part 4: Network Segmentation with VLANs (Optional)

For cyber range scenarios, you may want to segment VMs into different networks.

### VLAN Strategy

Create multiple isolated networks on top of the Arista network using VLAN tags:

- **VLAN 10:** Red Team network
- **VLAN 20:** Blue Team network
- **VLAN 30:** Target/Victim network
- **VLAN 40:** DMZ
- etc.

### Configuring VLANs in Proxmox

**No additional bridges needed.** Just use VLAN tags when creating VM network interfaces.

**When creating a VM:**
1. **Network** → **Bridge:** `vmbr0`
2. **VLAN Tag:** `10` (or 20, 30, etc.)

**Result:** VM is isolated to VLAN 10 and can only communicate with other VLAN 10 VMs.

### Arista Switch VLAN Configuration

If you want true VLAN isolation enforced by the switch:

```bash
# On Arista
configure terminal

# Create VLANs
vlan 10
   name RedTeam
vlan 20
   name BlueTeam
vlan 30
   name Targets

# Configure port-channels to trunk these VLANs
interface Port-Channel1-7
   switchport mode trunk
   switchport trunk allowed vlan 1,10,20,30,40

write memory
```

This allows VMs to use VLAN tags and the switch will enforce isolation.

---

## Part 5: Verification and Testing

### Network Verification Checklist

**For each node:**

- [ ] Can access Proxmox web UI via home network (192.168.1.x)
- [ ] bond0 shows all slaves active at correct speed
- [ ] vmbr0 bridge exists with bond0 as port
- [ ] Can ping other nodes via 10.10.10.x
- [ ] Ceph shows node as healthy member

**Cluster-wide:**

```bash
# Cluster status
pvecm status
# Should show: Quorate: Yes, all nodes listed

# Ceph status
ceph -s
# Should show: HEALTH_OK

# Ceph OSDs
ceph osd tree
# Should show all nodes with their OSDs

# Network connectivity
# From red1:
ping 10.10.10.12  # red2
ping 10.10.10.13  # red3
```

### Performance Testing

**Test bond throughput between nodes:**

```bash
# On red1
iperf3 -s

# On red2
iperf3 -c 10.10.10.11 -P 8 -t 30

# Should see ~18-20 Gbps (for 2-port bond) or ~38-40 Gbps (for red7's 4-port)
```

**Test Ceph performance:**

```bash
# Write test
rados bench -p cyberrange-vms 30 write

# Read test
rados bench -p cyberrange-vms 30 seq
```

### VM Creation Test

1. Create a test VM on red1 using Ceph storage and vmbr0 network
2. Verify VM has no home network access:
   ```bash
   # Inside VM
   ping 192.168.1.1  # Should FAIL
   ping 10.10.10.1   # Should work (if Arista is gateway)
   ```
3. Live migrate VM from red1 to red2
4. Verify migration used Arista network (check bond0 traffic)

---

## Part 6: Maintenance and Operations

### Adding More Storage

**When adding new disks to existing nodes:**

1. Click node → **Ceph** → **OSD**
2. Click **Create: OSD**
3. Select new disk
4. Wait for rebalancing to complete

```bash
ceph -s
# Monitor rebalancing progress
```

### Expanding the Cluster

**To add nodes 4-7:**

Follow "Part 2: Prepare for New Nodes" for each additional node.

**Order of operations:**
1. Install Proxmox with home network IP
2. Configure bond0 on Arista network
3. Join cluster
4. Create vmbr0 bridge
5. Install Ceph
6. Add OSDs

### Backup Strategy

**VM Backups:**

1. **Datacenter** → **Backup**
2. Configure backup schedule
3. **Storage:** Can use Ceph or external storage
4. **Mode:** Snapshot (best for Ceph)

**Cluster Configuration Backup:**

```bash
# Backup cluster config
tar -czf /root/pve-cluster-backup.tar.gz /etc/pve/

# Backup Ceph config
tar -czf /root/ceph-backup.tar.gz /etc/ceph/
```

Store backups on external storage, not on the cluster itself.

### Monitoring

**Built-in Proxmox monitoring:**
- **Summary** tab shows CPU, RAM, storage usage
- **Ceph** section shows cluster health
- **Tasks** shows recent operations

**External monitoring (recommended):**
- Grafana + Prometheus for detailed metrics
- Ceph dashboard (enabled via manager)
- Netdata for real-time system metrics

---

## Part 7: Troubleshooting

### Common Issues

**Issue: Cluster node shows offline**

```bash
# Check cluster services
systemctl status pve-cluster corosync

# Restart if needed
systemctl restart pve-cluster corosync

# Check network connectivity
ping 192.168.1.171  # red1
```

**Issue: Ceph unhealthy**

```bash
ceph -s
# Look for specific errors

# Common fixes:
ceph osd tree  # Check for down OSDs
ceph osd unset norebalance  # If stuck rebalancing
```

**Issue: VM migration fails**

```bash
# Check migration network config
cat /etc/pve/datacenter.cfg

# Should have:
migration: secure,network=10.10.10.0/24

# Test connectivity on Arista network
ping -I bond0 10.10.10.12
```

**Issue: Bond not negotiating LACP**

```bash
# Check bond status
cat /proc/net/bonding/bond0

# Check Arista side
# On Arista:
show port-channel summary
show lacp neighbor
```

**Issue: Can't access Proxmox web UI**

- Verify home network connectivity: `ping 192.168.1.171`
- Check if services are running: `systemctl status pveproxy`
- Try accessing via node's IP directly
- Check firewall rules

---

## Security Considerations

### Network Isolation

✅ **Correct:** VMs on 10.10.10.x network (vmbr0) - isolated from home network  
❌ **Wrong:** VMs on 192.168.1.x network - exposed to home network

### Firewall Rules

**On each Proxmox node:**

The default Proxmox firewall is disabled. For production:

1. **Datacenter** → **Firewall** → **Options**
2. Enable firewall
3. Create rules to allow:
   - SSH (port 22) from home network
   - Proxmox Web UI (port 8006) from home network
   - Corosync (ports 5404-5405) between cluster nodes
   - Ceph (ports 6789, 6800-7300) on Arista network
4. **Block all other traffic to management interfaces**

### Access Control

**Proxmox users:**
- Use role-based access control (RBAC)
- Create separate users for different teams (Red Team, Blue Team, etc.)
- Limit permissions appropriately

**VM Access:**
- Use SSH keys, not passwords
- Implement jump boxes for VM access
- Log all access for audit trails

---

## Quick Reference

### Key IP Addresses

| Component | Network | IP/Range |
|-----------|---------|----------|
| Arista Switch | Operational | 10.10.10.1 |
| Proxmox Nodes (management) | Home | 192.168.1.171-177 |
| Proxmox Nodes (operational) | Operational | 10.10.10.11-17 |
| VMs | Operational | 10.10.10.100+ |

### Key Commands

```bash
# Cluster status
pvecm status
pvecm nodes

# Ceph status
ceph -s
ceph osd tree
ceph df

# Network
ip a
cat /proc/net/bonding/bond0
brctl show

# Services
systemctl status pve-cluster corosync pvedaemon pveproxy
```

### File Locations

```
/etc/pve/                    # Cluster configuration
/etc/pve/corosync.conf       # Cluster membership
/etc/pve/datacenter.cfg      # Datacenter settings
/etc/pve/ceph.conf           # Ceph configuration
/etc/network/interfaces      # Network configuration
/proc/net/bonding/bond0      # Bond status
```

---

## Appendix: Complete Network Configuration Examples

### red1 - /etc/network/interfaces

```bash
# Loopback
auto lo
iface lo inet loopback

# 1G NIC - Home Network (Management)
auto eno1
iface eno1 inet static
    address 192.168.1.171/24
    gateway 192.168.1.1

# 10G Bond (LACP to Arista) - Operational Network
auto bond0
iface bond0 inet static
    address 10.10.10.11/24
    bond-slaves ens1f0 ens1f1
    bond-mode 802.3ad
    bond-miimon 100
    bond-lacp-rate fast
    bond-xmit-hash-policy layer3+4

auto ens1f0
iface ens1f0 inet manual
    bond-master bond0

auto ens1f1
iface ens1f1 inet manual
    bond-master bond0

# VM Bridge - Arista Network
auto vmbr0
iface vmbr0 inet manual
    bridge-ports bond0
    bridge-stp off
    bridge-fd 0
```

### Arista Switch Configuration (Complete)

```
configure terminal

# Management interface
interface Vlan1
   ip address 10.10.10.1/24
   no shutdown

# Port-Channels for all 7 nodes
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

interface Port-Channel7
   description red7-bond-40G
   switchport mode access
   switchport access vlan 1
   no shutdown

interface Ethernet25-28
   description red7-links-40G
   channel-group 7 mode active
   lacp timer fast
   no shutdown

write memory
```

---

## Document Status

**Current Configuration:**
- ✅ 3 nodes installed (red1, red2, red3)
- ✅ Proxmox cluster created
- ✅ Bond interfaces configured
- ⏳ Bridges (vmbr0) need to be created
- ⏳ Ceph needs to be configured
- ⏳ 4 additional nodes (red4-7) need to be added

**Next Steps:**
1. Create vmbr0 bridges on red1, red2, red3
2. Install and configure Ceph
3. Test VM creation and migration
4. Add remaining nodes (red4-7)

**Last Updated:** February 8, 2026

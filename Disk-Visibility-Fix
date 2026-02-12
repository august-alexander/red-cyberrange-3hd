# LSI MegaRAID 3108 - Enable JBOD Mode for Ceph

## Problem
Drives connected to LSI MegaRAID controller not visible in `lsblk` because they default to RAID mode.

## Solution

### 1. Fix Proxmox Repository Errors
```bash
# Disable enterprise repos (using .sources format)
mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.sources.bak
mv /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/ceph.sources.bak

# Add no-subscription repos
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
echo "deb http://download.proxmox.com/debian/ceph-squid trixie no-subscription" > /etc/apt/sources.list.d/ceph-no-subscription.list

apt update && apt upgrade -y
```

### 2. Install StorCLI
```bash
# Download from: https://docs.broadcom.com/docs/1232743397
# Transfer to server
scp ~/Downloads/007.2705.0000.0000_storcli_rel.zip root@red3:/tmp/

# On server:
cd /tmp
unzip 007.2705.0000.0000_storcli_rel.zip
cd storcli_rel
unzip Unified_storcli_all_os.zip
cd Unified_storcli_all_os/Linux/

# Extract and install
apt install rpm2cpio cpio -y
rpm2cpio storcli-*.rpm | cpio -idmv
cp ./opt/MegaRAID/storcli/storcli64 /usr/local/sbin/
chmod +x /usr/local/sbin/storcli64
```

### 3. Check Controller and Drives
```bash
# View controller info
storcli64 /c0 show

# View all drives
storcli64 /c0 /eall /sall show
```

### 4. Enable JBOD Mode
```bash
# Enable JBOD on controller (takes ~1 minute)
storcli64 /c0 set jbod=on

# Verify JBOD enabled
storcli64 /c0 show jbod

# Convert all drives to JBOD
storcli64 /c0 /e252 /s0-7 set jbod

# Verify drives are in JBOD mode
storcli64 /c0 /eall /sall show
# Look for "JBOD" in State column

# Check drives visible to OS
lsblk
```

### 5. Add to Ceph
```bash
# Via command line
pveceph osd create /dev/sdb
pveceph osd create /dev/sdc
# ... repeat for each drive

# Or use Proxmox GUI:
# Datacenter → Node → Ceph → OSD → Create: OSD
```

## Hardware Details
- Controller: LSI MegaRAID SAS-3 3108 (Broadcom/Avago)
- PCI Address: b3:00.0
- Drives: 8x 1.1TB SAS HDD (X425_HCBEP1T2A10)
- Enclosure ID: 252

## Notes
- JBOD mode allows Ceph to manage drives directly
- Alternative: Create single-disk RAID0 arrays (less ideal)
- Drives show as sdb-sdi after JBOD conversion

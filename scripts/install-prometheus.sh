#!/bin/bash

# Prometheus Installation Script for Ubuntu
# Run with sudo: sudo bash install_prometheus.sh

set -e

# Prompt for Grafana Cloud credentials
echo "[*] Grafana Cloud Configuration"
read -p "Enter Grafana Instance ID: " INSTANCE_ID
read -p "Enter Grafana API Key: " API_KEY
read -p "Enter Hostname for this node: " NODE_HOSTNAME

# Get latest version
echo "[*] Fetching latest Prometheus version..."
LATEST=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep tag_name | cut -d '"' -f 4 | tr -d 'v')
echo "[+] Latest version: $LATEST"

# Create prometheus user
echo "[*] Creating prometheus user..."
sudo useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || echo "User already exists"

# Create directories
echo "[*] Creating directories..."
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus

# Download and extract
echo "[*] Downloading Prometheus..."
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v${LATEST}/prometheus-${LATEST}.linux-amd64.tar.gz
tar xvfz prometheus-${LATEST}.linux-amd64.tar.gz
cd prometheus-${LATEST}.linux-amd64

# Install binaries
echo "[*] Installing binaries..."
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

# Create Custom yml to connect Node_Exporter and remote write to Grafana.

wget -O /etc/prometheus/prometheus.yml https://raw.githubusercontent.com/august-alexander/red-cyberrange-3hd/main/config/prometheus.yml 

# Substitute provided Values
sudo sed -i "s/ID_HERE/$INSTANCE_ID/" /etc/prometheus/prometheus.yml
sudo sed -i "s/API_KEY_HERE/$API_KEY/" /etc/prometheus/prometheus.yml
sudo sed -i "s/HOSTNAME_HERE/$NODE_HOSTNAME/" /etc/prometheus/prometheus.yml




# Set ownership
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus

# Create systemd service
echo "[*] Creating systemd service..."
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file=/etc/prometheus/prometheus.yml \\
    --storage.tsdb.path=/var/lib/prometheus/ \\
    --web.listen-address=0.0.0.0:9090

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start service
echo "[*] Starting Prometheus..."
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Cleanup
echo "[*] Cleaning up..."
rm -rf /tmp/prometheus-${LATEST}.linux-amd64*

# Verify
echo "[*] Verifying installation..."
sleep 2
if systemctl is-active --quiet prometheus; then
    echo "[+] Prometheus is running!"
    echo "[+] Web UI: http://$(hostname -I | awk '{print $1}'):9090"
    echo "[+] Config file: /etc/prometheus/prometheus.yml"
else
    echo "[-] Something went wrong. Check: sudo systemctl status prometheus"
fi

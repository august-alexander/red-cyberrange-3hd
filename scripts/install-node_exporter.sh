#!/bin/bash


# Get the latest version number from GitHub
LATEST=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep tag_name | cut -d '"' -f 4 | tr -d 'v')

# Download the tarball
wget https://github.com/prometheus/node_exporter/releases/download/v${LATEST}/node_exporter-${LATEST}.linux-amd64.tar.gz

tar xvfz node_exporter-${LATEST}.linux-amd64.tar.gz

sudo mv node_exporter-${LATEST}.linux-amd64/node_exporter /usr/local/bin/

rm -rf node_exporter*


sudo useradd --no-create-home --shell /bin/false node_exporter


sudo tee /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF


sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

sudo systemctl status node_exporter
curl http://localhost:9100/metrics | head

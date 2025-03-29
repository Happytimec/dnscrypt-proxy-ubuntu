#!/bin/bash

echo "📦 安裝 dnscrypt-proxy..."
sudo apt update
sudo apt install -y dnscrypt-proxy curl

echo "🛠 建立設定檔..."

CONFIG_FILE="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
sudo systemctl stop dnscrypt-proxy

sudo tee $CONFIG_FILE > /dev/null <<EOF
listen_addresses = ['127.0.0.1:53', '[::1]:53']
server_names = ['cloudflare', 'cloudflare-ipv6', 'google', 'google-ipv6']
max_clients = 250
ipv4_servers = true
ipv6_servers = true
doh_servers = true
dnscrypt_servers = false
require_dnssec = true
require_nolog = true
require_nofilter = true
fallback_resolver = '9.9.9.9:53'
block_ipv6 = false
EOF

echo "🔧 修改 systemd-resolved 設定..."
sudo sed -i '/^#*DNS=/c\DNS=127.0.0.1 ::1' /etc/systemd/resolved.conf
sudo sed -i '/^#*DNSStubListener=/c\DNSStubListener=no' /etc/systemd/resolved.conf

echo "🔄 重啟服務..."
sudo systemctl restart dnscrypt-proxy
sudo systemctl restart systemd-resolved

echo "✅ 測試解析 google.com..."
dig google.com | grep -A 1 "ANSWER SECTION"

echo "✅ 顯示使用中的 DNS 伺服器..."
dnscrypt-proxy -resolve google.com | grep -E "Server|Protocol|IP"

echo "🎉 完成！dnscrypt-proxy 安裝並啟用了 Cloudflare + Google DoH（IPv4+IPv6）"


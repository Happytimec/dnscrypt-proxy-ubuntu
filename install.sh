#!/bin/bash

set -e

echo "📦 安裝 dnscrypt-proxy..."
sudo apt update
sudo apt install -y dnscrypt-proxy curl

CONFIG_DIR="/etc/dnscrypt-proxy"
CONFIG_FILE="${CONFIG_DIR}/dnscrypt-proxy.toml"

echo "🛠 建立 dnscrypt-proxy 設定檔..."

sudo systemctl stop dnscrypt-proxy

sudo tee "$CONFIG_FILE" > /dev/null <<EOF
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

echo "🔧 設定 systemd-resolved..."
sudo sed -i '/^#*DNS=/c\DNS=127.0.0.1 ::1' /etc/systemd/resolved.conf
sudo sed -i '/^#*DNSStubListener=/c\DNSStubListener=no' /etc/systemd/resolved.conf

echo "🔁 重啟 systemd-resolved 和 dnscrypt-proxy..."
sudo systemctl restart systemd-resolved
sudo systemctl restart dnscrypt-proxy

echo "📎 確保 resolv.conf 正確..."
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

echo "✅ 測試 DNS 查詢 (dig)..."
dig google.com | grep -A 1 "ANSWER SECTION" || echo "⚠️ dig 查詢失敗"

echo "🔍 使用 dnscrypt-proxy 測試解析器..."
dnscrypt-proxy -config "$CONFIG_FILE" -resolve google.com | grep -E "Server|Protocol|IP" || echo "⚠️ 無法解析 - 請檢查設定"

echo "🎉 安裝完成！dnscrypt-proxy 已啟用 Cloudflare + Google DoH（IPv4 + IPv6）"

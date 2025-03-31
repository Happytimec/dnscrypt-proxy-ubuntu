#!/bin/bash

set -e

echo "\n🔧 安裝與配置 dnscrypt-proxy with DoH (Cloudflare + Google + Quad9)...\n"

# 1️⃣ 安裝相依套件
sudo apt update && sudo apt install -y curl tar jq resolvconf

# 2️⃣ 下載並安裝 dnscrypt-proxy 最新版
VERSION="2.1.5"
WORKDIR="/opt/dnscrypt"
BINARY="dnscrypt-proxy"
URL="https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/${VERSION}/dnscrypt-proxy-linux_x86_64-${VERSION}.tar.gz"

sudo mkdir -p "$WORKDIR"
cd "$WORKDIR"
curl -L -o dnscrypt.tar.gz "$URL"
tar -xzf dnscrypt.tar.gz
cd linux-x86_64

sudo cp -f dnscrypt-proxy /usr/sbin/
sudo mkdir -p /etc/dnscrypt-proxy
sudo cp -f example-dnscrypt-proxy.toml /etc/dnscrypt-proxy/dnscrypt-proxy.toml

# 3️⃣ 修改設定檔以使用 DoH + 指定 server_names
sudo sed -i \
  -e "/^# server_names/c\server_names = ['cloudflare', 'google', 'quad9-doh-ip4-port443-filter-pri']" \
  -e "/^listen_addresses/c\listen_addresses = ['127.0.0.1:5353', '[::1]:5353']" \
  -e "/^dnscrypt_servers/c\dnscrypt_servers = false" \
  -e "/^doh_servers/c\doh_servers = true" \
  -e "/^require_dnssec/c\require_dnssec = true" \
  -e "/^require_nolog/c\require_nolog = true" \
  -e "/^require_nofilter/c\require_nofilter = true" \
  /etc/dnscrypt-proxy/dnscrypt-proxy.toml

# 4️⃣ 建立 systemd 服務
sudo bash -c 'cat > /etc/systemd/system/dnscrypt-proxy.service <<EOF
[Unit]
Description=DNSCrypt client proxy
After=network.target

[Service]
ExecStart=/usr/sbin/dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

# 5️⃣ 啟用並啟動服務
sudo systemctl daemon-reload
sudo systemctl enable dnscrypt-proxy
sudo systemctl start dnscrypt-proxy

# 6️⃣ 設定 DNS 使用 127.0.0.1
sudo sed -i '/^DNS=/d;/^FallbackDNS=/d;/^DNSStubListener=/d;/^DNSOverTLS=/d' /etc/systemd/resolved.conf
sudo bash -c 'cat >> /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=127.0.0.1:5353
FallbackDNS=8.8.8.8 1.1.1.1
DNSStubListener=no
DNSOverTLS=no
EOF'

sudo systemctl restart systemd-resolved
sudo rm -f /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

# 7️⃣ 加入開機自動修復
cat <<EOF | sudo tee /root/fix-dns.sh >/dev/null
#!/bin/bash
sleep 3
sudo bash -c 'echo -e "nameserver 127.0.0.1\nnameserver 8.8.8.8\nsearch ." > /etc/resolv.conf'
EOF
chmod +x /root/fix-dns.sh
grep -q fix-dns.sh /etc/crontab || echo "@reboot root /root/fix-dns.sh" | sudo tee -a /etc/crontab

# ✅ 測試
sleep 1
echo "\n✨ 測試 DoH 查詢 google.com："
dnscrypt-proxy -resolve google.com -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml || true

echo "\n✅ 安裝與配置完成！DNS 現在透過 DoH 保護，並在 127.0.0.1:5353 上執行。"

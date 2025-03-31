#!/bin/bash

set -e

### ✨ DNSCrypt-Proxy + DoH 自動安裝與配置自動化腳本
### 作者: HappyTime
### GitHub 使用版本

DNSCRYPT_VER="2.1.5"
DNSCRYPT_DIR="/etc/dnscrypt-proxy"
SYSTEMD_SERVICE="/etc/systemd/system/dnscrypt-proxy.service"

## 1. 移除舊有 dnscrypt-proxy
systemctl stop dnscrypt-proxy || true
systemctl disable dnscrypt-proxy || true
apt remove -y dnscrypt-proxy || true
rm -rf "$DNSCRYPT_DIR"
mkdir -p "$DNSCRYPT_DIR"

## 2. 下載 & 解壓
cd /opt
curl -L -o dnscrypt-proxy.tar.gz https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/$DNSCRYPT_VER/dnscrypt-proxy-linux_x86_64-$DNSCRYPT_VER.tar.gz
mkdir -p /opt/dnscrypt-tmp && tar -xzf dnscrypt-proxy.tar.gz -C /opt/dnscrypt-tmp --strip-components=1
cp /opt/dnscrypt-tmp/dnscrypt-proxy /usr/sbin/
cp /opt/dnscrypt-tmp/example-dnscrypt-proxy.toml "$DNSCRYPT_DIR/dnscrypt-proxy.toml"

## 3. 修改配置檔
sed -i "s/^# server_names =.*/server_names = ['cloudflare', 'google', 'quad9-doh-ip4-port443-filter-pri']/" $DNSCRYPT_DIR/dnscrypt-proxy.toml
sed -i "s/^listen_addresses =.*/listen_addresses = ['127.0.0.1:5353', '[::1]:5353']/" $DNSCRYPT_DIR/dnscrypt-proxy.toml
sed -i "s/^#\? ipv4_servers =.*/ipv4_servers = true/" $DNSCRYPT_DIR/dnscrypt-proxy.toml
sed -i "s/^#\? ipv6_servers =.*/ipv6_servers = true/" $DNSCRYPT_DIR/dnscrypt-proxy.toml
sed -i "s/^#\? doh_servers =.*/doh_servers = true/" $DNSCRYPT_DIR/dnscrypt-proxy.toml
sed -i "s/^#\? dnscrypt_servers =.*/dnscrypt_servers = false/" $DNSCRYPT_DIR/dnscrypt-proxy.toml

## 4. systemd service
cat > $SYSTEMD_SERVICE <<EOF
[Unit]
Description=DNSCrypt client proxy
After=network.target

[Service]
ExecStart=/usr/sbin/dnscrypt-proxy -config $DNSCRYPT_DIR/dnscrypt-proxy.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dnscrypt-proxy
systemctl start dnscrypt-proxy

## 5. 配置 systemd-resolved
cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=127.0.0.1:5353
FallbackDNS=1.1.1.1 8.8.8.8
DNSStubListener=no
DNSOverTLS=no
EOF

systemctl restart systemd-resolved
rm -f /etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

## 6. 啟動自動修復腳本 (cron)
cat > /root/fix-dnscrypt-dns.sh <<EOF
#!/bin/bash
sleep 10
echo "nameserver 127.0.0.1" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "search ." >> /etc/resolv.conf
EOF
chmod +x /root/fix-dnscrypt-dns.sh

(crontab -l 2>/dev/null; echo "@reboot /root/fix-dnscrypt-dns.sh") | crontab -u root -

## 7. 測試
sleep 1
if dig google.com @127.0.0.1 -p 5353 +short >/dev/null; then
    echo "\n✅ DNSCrypt + DoH 已啟用並可正常解析"
else
    echo "\n❌ DNSCrypt 解析失敗，請檢查 /etc/resolv.conf 或 systemd-resolved 狀態"
fi

exit 0

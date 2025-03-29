#!/bin/bash

set -e

echo "🛠 停用 systemd-resolved..."
sudo systemctl disable --now systemd-resolved
sudo systemctl disable --now dnscrypt-proxy.socket

echo "🔧 設定 /etc/systemd/resolved.conf..."
sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNS=127.0.0.1 ::1
DNSStubListener=no
EOF

echo "🔗 修正 resolv.conf → 127.0.0.1"
sudo rm -f /etc/resolv.conf
echo -e "nameserver 127.0.0.1\nnameserver ::1" | sudo tee /etc/resolv.conf

echo "🧾 修正 dnscrypt-proxy 設定檔 listen_addresses..."
CONFIG_FILE="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
if [ -f "$CONFIG_FILE" ]; then
  sudo sed -i "s/^listen_addresses.*/listen_addresses = \['127.0.0.1:53', '\[::1\]:53'\]/" "$CONFIG_FILE"
else
  echo "❗ 找不到設定檔，請確認 dnscrypt-proxy 是否已安裝。"
  exit 1
fi

echo "🔄 重啟 dnscrypt-proxy..."
sudo systemctl restart dnscrypt-proxy
sleep 2

STATUS=$(systemctl is-active dnscrypt-proxy)
if [ "$STATUS" != "active" ]; then
  echo "❌ dnscrypt-proxy 啟動失敗，請手動檢查設定檔。"
  sudo journalctl -u dnscrypt-proxy --no-pager | tail -20
  exit 1
fi

echo "✅ dnscrypt-proxy 啟動成功！"

echo "🧪 測試 dig google.com"
dig google.com @127.0.0.1 | grep -A1 "ANSWER SECTION" || echo "⚠️ dig 失敗"

echo "🧪 測試 dnscrypt-proxy -resolve"
dnscrypt-proxy -config "$CONFIG_FILE" -resolve google.com | grep -E "Protocol|Server|IP" || echo "⚠️ 解析失敗"

echo "🎉 修復完成！dnscrypt-proxy + DoH 現已運作"

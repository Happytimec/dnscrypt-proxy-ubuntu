#!/bin/bash

set -e

echo "🛠 停用 systemd-resolved 和 dnscrypt-proxy.socket..."
sudo systemctl disable --now systemd-resolved || true
sudo systemctl disable --now dnscrypt-proxy.socket || true

echo "🔧 設定 /etc/systemd/resolved.conf..."
sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNS=127.0.0.1 ::1
DNSStubListener=no
EOF

echo "🔗 設定 /etc/resolv.conf 指向 127.0.0.1:5353"
sudo rm -f /etc/resolv.conf
echo -e "nameserver 127.0.0.1\noptions port:5353" | sudo tee /etc/resolv.conf

echo "🧾 修改 dnscrypt-proxy 設定檔 listen_addresses → 5353"
CONFIG_FILE="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
if [ -f "$CONFIG_FILE" ]; then
  sudo sed -i "s/^listen_addresses.*/listen_addresses = \['127.0.0.1:5353', '\[::1\]:5353'\]/" "$CONFIG_FILE"
else
  echo "❗ 找不到設定檔：$CONFIG_FILE，請確認 dnscrypt-proxy 是否已安裝。"
  exit 1
fi

echo "🔄 重新啟動 dnscrypt-proxy..."
sudo systemctl restart dnscrypt-proxy
sleep 2

STATUS=$(systemctl is-active dnscrypt-proxy)
if [ "$STATUS" != "active" ]; then
  echo "❌ dnscrypt-proxy 無法啟動，請執行："
  echo "   sudo journalctl -u dnscrypt-proxy --no-pager | tail -20"
  exit 1
fi

echo "✅ dnscrypt-proxy 啟動成功！"

echo "🧪 dig 測試 google.com -p 5353"
dig google.com @127.0.0.1 -p 5353 | grep -A1 "ANSWER SECTION" || echo "⚠️ dig 查詢失敗"

echo "🧪 dnscrypt-proxy -resolve 測試"
dnscrypt-proxy -config "$CONFIG_FILE" -resolve google.com | grep -E "Protocol|Server|IP" || echo "⚠️ 查詢失敗"

echo "🎉 完成！現在 dnscrypt-proxy 已綁定 127.0.0.1:5353 並運作中"

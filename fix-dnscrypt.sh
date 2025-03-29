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

echo "🔗 修正 /etc/resolv.conf → 指向本地"
sudo rm -f /etc/resolv.conf
echo -e "nameserver 127.0.0.1\nnameserver ::1" | sudo tee /etc/resolv.conf

echo "🧾 檢查 dnscrypt-proxy 設定檔 listen_addresses..."
CONFIG_FILE="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
if [ -f "$CONFIG_FILE" ]; then
  sudo sed -i "s/^listen_addresses.*/listen_addresses = \['127.0.0.1:53', '\[::1\]:53'\]/" "$CONFIG_FILE"
else
  echo "❗ 找不到設定檔：$CONFIG_FILE，請確認 dnscrypt-proxy 是否已安裝。"
  exit 1
fi

echo "🔄 重新啟動 dnscrypt-proxy..."
sudo systemctl restart dnscrypt-proxy
sleep 2

STATUS=$(systemctl is-active dnscrypt-proxy)
if [ "$STATUS" != "active" ]; then
  echo "❌ dnscrypt-proxy 無法啟動，請檢查設定或執行以下指令查看錯誤："
  echo "   sudo journalctl -u dnscrypt-proxy --no-pager | tail -20"
  exit 1
fi

echo "✅ dnscrypt-proxy 已啟動！"

echo "🧪 dig 測試：google.com"
dig google.com @127.0.0.1 | grep -A1 "ANSWER SECTION" || echo "⚠️ dig 查詢失敗"

echo "🧪 dnscrypt-proxy 解析測試"
dnscrypt-proxy -config "$CONFIG_FILE" -resolve google.com | grep -E "Protocol|Server|IP" || echo "⚠️ dnscrypt-proxy 查詢失敗"

echo "🎉 修復完成！dnscrypt-proxy 現已正常啟用並接管 DNS"

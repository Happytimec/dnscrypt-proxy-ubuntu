#!/bin/bash

set -e

echo "🛠 停用 systemd-resolved..."
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

echo "🔗 修正 resolv.conf → 127.0.0.1"
sudo rm -f /etc/resolv.conf
echo -e "nameserver 127.0.0.1\nnameserver ::1" | sudo tee /etc/resolv.conf

echo "🧾 檢查並修正 dnscrypt-proxy 設定檔 listen_addresses..."
CONFIG_FILE="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
if [ -f "$CONFIG_FILE" ]; then
  sudo sed -i "s/^listen_addresses.*/listen_addresses = \['127.0.0.1:53', '\[::1\]:53'\]/" "$CONFIG_FILE"
else
  echo "❗ 找不到設定檔，請確認 dnscrypt-proxy 是否已安裝。"
  exit 1
fi

echo "🔄 重新啟動 dnscrypt-proxy..."
sudo systemctl restart dnscrypt-proxy
sleep 2

STATUS=$(systemctl is-active dnscrypt-proxy)
if [ "$STATUS" != "active" ]; then
  echo "❌ dnscrypt-proxy 無法啟動，請手動檢查設定檔。"
  sudo journalctl -u dnscrypt-proxy --no-pager | tail -20
  exit 1
fi

echo "✅ dnscrypt-proxy 啟動成功！"

echo "🧪 測試 dig google.com"
dig google.com @127.0.0.1 | grep -A1 "ANSWER SECTION" || echo "⚠️ dig 失敗"

echo "🧪 測試 dnscrypt-proxy -resolve"
dnscrypt-proxy -config "$CONFIG_FILE" -resolve google.com | grep -E "Protocol|Server|IP" || echo "⚠️ 解析失敗"

echo "🎉 修復完成！現在你的系統應該已使用 dnscrypt-proxy + DoH 作為主要 DNS"

#!/bin/bash

set -e

echo "🔧 停用 dnscrypt-proxy.socket 避免端口衝突..."
sudo systemctl disable --now dnscrypt-proxy.socket || true

echo "🧽 修正設定檔中的 minisign_key..."
sudo sed -i "s/minisign_key = .*/minisign_key = 'Ed+SRpye8Mfxp\/QuzI5D82YpN0Z4DjYcAydksfURHGsIP8j27lWy4fGg'/" /etc/dnscrypt-proxy/dnscrypt-proxy.toml

echo "🌐 強制用 IP 下載 public-resolvers.md（繞過 DNS 問題）..."
sudo curl --resolve download.dnscrypt.info:443:195.201.225.132 -o /etc/dnscrypt-proxy/public-resolvers.md https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md

echo "🔄 重啟 dnscrypt-proxy..."
sudo systemctl restart dnscrypt-proxy

sleep 2
echo "📈 檢查服務狀態..."
sudo systemctl status dnscrypt-proxy | head -15

echo "🧪 dig 測試 google.com"
dig google.com @127.0.0.1 -p 5353 | grep -A1 "ANSWER SECTION" || echo "❌ dig 查詢失敗"

echo "🧪 dnscrypt-proxy -resolve 測試"
dnscrypt-proxy -resolve google.com -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml | grep -E "Protocol|Server|IP" || echo "❌ dnscrypt 測試失敗"

echo "🎉 修復完成！如果你看到正常解析表示成功。"

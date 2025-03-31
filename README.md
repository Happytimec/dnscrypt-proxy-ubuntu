# dnscrypt-proxy-ubuntu
# DNSCrypt + DoH 安裝與自動化設定腳本

這個專案提供一個一鍵安裝與設定 `dnscrypt-proxy` 的自動化腳本，支援 DNS-over-HTTPS (DoH)，自動修復 DNS 問題，並與 V2Ray/Xray 無縫整合。

---

## 🧩 功能說明

- ✅ 自動下載並安裝最新版 `dnscrypt-proxy` (v2.1.5)
- ✅ 自動設定 Cloudflare、Google、Quad9 為 DoH 伺服器
- ✅ 啟用 IPv4 + IPv6
- ✅ 本機監聽 `127.0.0.1:5353`
- ✅ 自動建立 systemd 服務
- ✅ 開機自動修復 `resolv.conf`
- ✅ 支援 V2Ray / Xray DNS 指向 `localhost`

---

## 📦 安裝方式

```bash
curl -O https://your-repo-url/dnscrypt-doh-installer.sh
sudo bash dnscrypt-doh-installer.sh
```

> 📌 請確認執行者有 `root` 權限

---

## ⚙️ 系統需求

- Ubuntu 20.04+ / Debian 10+
- 已安裝 curl、systemd、dig (可選)
- 可使用 systemd-resolved

---

## 🧪 測試是否正常

```bash
dnscrypt-proxy -resolve google.com -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml
dig google.com @127.0.0.1 -p 5353 +short
```

---

## 🛠️ 常見整合 (V2Ray/Xray)

將 `/etc/v2ray-agent/xray/conf/11_dns.json` 修改為：

```json
{
  "dns": {
    "servers": [
      "https://127.0.0.1:5353"
    ]
  }
}
```

---

## 🧰 Crontab 自動修復建議

```bash
@reboot /root/fix-dnscrypt-dns.sh
@reboot /root/switch_dns_to_5353.sh
```

---

## 📁 目錄說明

| 檔案名稱 | 說明 |
|-----------|------|
| dnscrypt-doh-installer.sh | 主安裝腳本 |
| fix-dnscrypt-dns.sh | 修復 DNS 問題（resolv.conf、systemd） |
| switch_dns_to_5353.sh | 切換 DNS 指向 `127.0.0.1:5353` |

---

## 🤝 貢獻

歡迎提交 pull request 或建立 issue。這個專案目標是提供穩定、安全、快速的 DNS-over-HTTPS 解決方案。

---

## 📜 授權

MIT License

---

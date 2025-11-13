---

# **v2bx-auto-setup**

一键安装 & 配置 **V2bX 后端节点**（支持普通节点 / 家宽 S5 节点 / CDN DNS 证书节点）

本项目提供一个完全自动化的 Bash 脚本，用于自动生成并写入 **V2bX 后端所需的全部配置文件**：

* `/etc/V2bX/config.json`
* `/etc/V2bX/route.json`
* `/etc/V2bX/dns.json`
* `/etc/V2bX/custom_outbound.json`

所有模板均已内置，无需外部文件。

---

## **📌 功能特点**

### ✅ 支持三类节点自动配置

* **普通 VLESS 节点（单节点）**
* **家宽 Socks5 节点（支持用户/密码或匿名 S5）**
* **CDN 节点（Cloudflare DNS 自动申请 TLS 证书）**

---

### ✅ 自动生成全部 V2bX 配置文件

无需用户手动编辑 JSON，脚本直接生成完整配置。

---

### ✅ Cloudflare DNS ACME 自动证书

CDN 模式下会自动：

* 写入 `CLOUDFLARE_EMAIL`
* 写入 `CLOUDFLARE_API_KEY`
* 自动申请证书（fullchain.cer / cert.key）

证书模式固定为：

```
Email: v2bx@github.com
Mode: dns
Provider: Cloudflare
```

---

### ✅ 内置公用 DNS 模板

全局通用：

* Cloudflare
* Google
* Quad9
* 阿里 / 腾讯（国内域名走这两个）

---

### ✅ 自动安装全局命令 fxx

脚本运行后自动安装命令：

```
fxx
```

可在任何路径快速重新启动脚本。

---

### ✅ 交互式界面美观清晰

* 大型 ASCII Banner（风萧萧标题）
* 中文交互提示
* 数字选择
* 校验输入（节点 ID 必须为数字）

---

## ---------------------------------------

# **📥 1. 下载脚本**

```bash
wget https://raw.githubusercontent.com/hubentuan/v2bx-auto-setup/main/v2bx_setup.sh
chmod +x v2bx_setup.sh
```

---

# **▶️ 2. 运行脚本**

```bash
sudo ./v2bx_setup.sh
```

或使用全局命令重新打开：

```bash
fxx
```

---

# **🧩 3. 选择节点类型**

```
1) 配置普通 VLESS 单节点
2) 配置家宽 Socks5 节点
3) 配置 CDN 节点（Cloudflare DNS 自动证书）
q) 退出脚本
```

---

## **📌 CDN 模式说明（必读）**

CDN 证书节点需要 Cloudflare DNS 自动验证，注意：

1. 将证书域名添加到 Cloudflare
2. 将该域名解析到你的服务器 IP
3. **关闭小黄云（仅 DNS）**
4. 脚本会要求输入：

   * 证书域名
   * Cloudflare 邮箱
   * Cloudflare Global API Key
5. 配置完成后，重启 V2bX 查看日志
6. 当你看到证书申请成功后，再重新打开小黄云，开始走 CDN

---

---

# **🖥️ 支持系统**

* Debian / Ubuntu / CentOS / Rocky / AlmaLinux / OpenEuler
* 需要已安装：

  * V2bX
  * jq
  * systemd

---

# **⚠️ 安全说明**

脚本默认不包含任何敏感信息。
所有 ApiHost / ApiKey / Cloudflare 信息均由用户手动输入。

---

# **📣 作者**

**hubentuan**

项目地址：
👉 [https://github.com/hubentuan/v2bx-auto-setup](https://github.com/hubentuan/v2bx-auto-setup)

---
